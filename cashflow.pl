#!/usr/bin/perl -w

use strict;
use warnings;
use Data::Dumper;
use DateTime;
use List::Util qw(sum);
use Scalar::Util qw(looks_like_number);

my $definitions;
my $input;
my $cash_flow;
my @types;

$definitions = main::get_definitions();

my $run_timestamp = 2; # 2 years. this is hardcoded, not good

#-------------------------------------------------------------------------------
# Source: https://metacpan.org/source/SBURKE/Number-Latin-1.01/Latin.pm
#-------------------------------------------------------------------------------
sub int2latin ($) {
  # Source: https://metacpan.org/source/SBURKE/Number-Latin-1.01/Latin.pm
  return undef unless defined $_[0];
  return '0' if $_[0] == 0;
  return '-' . _i2l( abs int $_[0] ) if $_[0] <= -1;
  return       _i2l(     int $_[0] );
}
 
{
  my @alpha = ('a' .. 'z'); 
  # Source: https://metacpan.org/source/SBURKE/Number-Latin-1.01/Latin.pm
  sub _i2l { # the real work
    my $int = shift(@_) || return "";
    _i2l(int (($int - 1) / 26)) . $alpha[$int % 26 - 1];  # yes, recursive
  }
}
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Read input csv file and convert to $input hash
#-------------------------------------------------------------------------------

my $typeno=0;
my $lastcolumn="";

while (<>) {
 
  s/\R/\n/g;
  chomp;
  my $line = $_;
  
  next if( $line =~ /^\s*$|\s*#/);
  next if( $. == 1); # why?
  
  $line =~ s/,\s*$/, /g; # This is a hack!
  
  my @line = split(/,/, $line );
  
  if( scalar @line ne 6 ) {
    die( "\nERROR: on line $. [$line] does not have 6 columns, as it should\n");
  }
  
  my ($type, $amount, $cycle_start, $frequency, $occurances, $comment ) = split(/,/, $line );
  
  $cycle_start =~ s/\s//g; # remove blanks around date
  
  if( exists $input ->{$type} ) {
    die("\nERROR: $type already exists in the input file\n");    
  }
  
  if (! looks_like_number($amount)) {
    die("\nERROR: on line $. [$line] has a none numeric value for the amount!\n");
  }
  
  if( $cycle_start =~ /^(\d{4})-(\d{2})-(\d{2})$/ ) {
    $input->{$type}->{cycle_start_year}  = $1;
    $input->{$type}->{cycle_start_month} = $2;
    $input->{$type}->{cycle_start_day}   = $3;
  } else {
    die("\nERROR: on line $. [$line] has an improperly formatted date! The only permitted format is %Y-%m-%d\n");    
  }
  
  if( $frequency =~ /^\s*\w+\s*\=\>\s*\d+\s*$/ ) {
    $definitions->{"$frequency"}->{string}            = "$frequency";
    $definitions->{"$frequency"}->{cycles_per_year}   = 1; #tbd
  }
  
  if( ! exists $definitions->{$frequency} ) {
    die("\nERROR: line $. [$line] has a frequency of [$frequency] which is not defined\n");
  }

  $input->{$type}->{amount}      = $amount;
  $input->{$type}->{cycle_start} = $cycle_start;
  $input->{$type}->{frequency}   = $frequency;
  $input->{$type}->{occurances}  = $occurances; # number of occurances
  $input->{$type}->{comment}     = $comment;
  $input->{$type}->{linenumber}  = $.; # this includes comment lines, this is not a data linenumber
  $input->{$type}->{line}        = $line;
  $input->{$type}->{cycles}      = $definitions->{$frequency}->{cycles_per_year}*$run_timestamp;
  $input->{$type}->{colname}     = int2latin($typeno+4); # adds column letter name for spreadsheets, rows will come later
  $input->{$type}->{typeno}      = $typeno;
  
  $lastcolumn = uc($input->{$type}->{colname}); # need this so as to print something like =SUM(D2:AW2), etc.

  push( @types, $type ); # order of rows, i.e. types, from in input file, which will become columns in the output

  $typeno++;
  
}

foreach my $type ( sort keys %{$input} ) {
  
  my $cycle_start = $input->{$type}->{cycle_start};
  my $year        = $input->{$type}->{cycle_start_year};
  my $month       = $input->{$type}->{cycle_start_month};
  my $day         = $input->{$type}->{cycle_start_day};
  my $amount      = $input->{$type}->{amount};
  my $frequency   = $definitions->{$input->{$type}->{frequency}}->{string};
  my $cycles      = $input->{$type}->{cycles};
  
  my $d = $cycle_start;
  
  $cash_flow->{$d}->{$type}=$amount;
   
  for (my $n=0; $n <= $cycles-1; $n++) {

   my $dt = DateTime->new( year => $year, month => $month, day => $day );
   $dt->add( eval $frequency );

   # New year, month and day, after adding $frequency
   $year  = $dt->year;
   $month = $dt->month;
   $day   = $dt->day;

   $d = sprintf("%4d-%02d-%02d", $year, $month, $day );
   
   $cash_flow->{$d}->{$type}=$amount;
   
  }
  
}

my $cf;

# Need to improve the below
foreach my $date ( sort keys %{$cash_flow} ) { # sort by $date
  
  my @amounts;
  
  foreach my $type ( @types ) {
    
    my $amount = '';
    
    if( exists $cash_flow->{$date}->{$type} ) {
      push( @amounts, $cash_flow->{$date}->{$type} );
    } else {
      push( @amounts, '');
    }

    $cf->{$date} = [ @amounts ];
    
  }

}


# main:
print "date,REMAINING ON DATE,SUM ON DATE," . join( ",", @types) . "\n";

my $rowno=2; # 2 because header and spreadsheets starts with a 1, i.e. 1+1

foreach my $date ( sort keys %{$cf} ) {
  
  my $rownoprevious = $rowno-1;
  
  my @amounts = @{$cf->{$date}};
  my $columns = scalar @amounts;
  
  # @plain= grep { $_ ne '' } @plain;
  my $sum_on_date       = "=sum(D${rowno}:${lastcolumn}${rowno})";   
  
  my $remaining_on_date;
  
  if( $rownoprevious eq 1 ) {
    $remaining_on_date = "=C${rowno}";    
  } else {
    $remaining_on_date = "=B${rownoprevious}+C${rowno}";
  }
  print "$date,$remaining_on_date,$sum_on_date," . join( ",", @amounts) . "\n";
 
  $rowno++;
  
}


#exit;

sub get_definitions {
  
  # String is to be used with DateTime module
  
  $definitions->{yearly}->{string}            = 'years => 1';
  $definitions->{yearly}->{cycles_per_year}   = 1;

  $definitions->{biennial}->{string}          = 'years => 2';
  $definitions->{biennial}->{cycles_per_year} = 0.5;

  $definitions->{biannual}->{string}          = 'months => 6';
  $definitions->{biannual}->{cycles_per_year} = 2;

  $definitions->{semiannual}->{string}          = 'months => 6';
  $definitions->{semiannual}->{cycles_per_year} = 2;
  
  $definitions->{monthly}->{string}           = 'months => 1';
  $definitions->{monthly}->{cycles_per_year}  = 12;
  
  $definitions->{biweekly}->{string}          = 'weeks => 2';
  $definitions->{biweekly}->{cycles_per_year} = 26;
  
  $definitions->{weekly}->{string}            = 'weeks => 1';
  $definitions->{weekly}->{cycles_per_year}   = 52;
  
  $definitions->{daily}->{string}             = 'days => 1';
  $definitions->{daily}->{cycles_per_year}    = 365; # of course may be 366
  
  $definitions->{quarterly}->{string}          = 'months => 3';
  $definitions->{quarterly}->{cycles_per_year} = 4;  

  $definitions->{once}->{string}               = 'days => 0';
  $definitions->{once}->{cycles_per_year}      = 0;  
  
  return $definitions;

}

