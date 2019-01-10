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
my @order;

$definitions = main::get_definitions();

my $run_timestamp = 2; # 2 years. this is hardcoded, not good

#-------------------------------------------------------------------------------
# Read input csv file and convert to $input hash
#-------------------------------------------------------------------------------
while (<>) {
 
  s/\R/\n/g;
  chomp;
  my $line = $_;
  
  next if( $line =~ /^\s*$|\s*#/);
  next if( $. == 1); # why?
  
  $line =~ s/,\s*$/, /g; # This is a hack!
  
  my @line = split(/,/, $line );
  
  if( scalar @line ne 5 ) {
    die( "\nERROR: on line $. [$line] does not have 5 columns, as it should\n");
  }
  
  my ($type, $amount, $cycle_start, $frequency, $comment ) = split(/,/, $line );
  
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
  
  if( ! exists $definitions->{$frequency} ) {
    die("\nERROR: line $. [$line] has a frequency of [$frequency] which is not defined\n");
  }

  $input->{$type}->{amount}      = $amount;
  $input->{$type}->{cycle_start} = $cycle_start;
  $input->{$type}->{frequency}   = $frequency;
  $input->{$type}->{comment}     = $comment;
  $input->{$type}->{linenumber}  = $.;
  $input->{$type}->{line}        = $line;
  $input->{$type}->{cycles}      = $definitions->{$frequency}->{cycles_per_year}*$run_timestamp;
  
  push( @order, $type ); # order of rows in input file, which will become columns in the output
 
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
foreach my $date ( sort keys %{$cash_flow} ) {
  
  my @amounts;
  
  foreach my $column_name ( @order ) {
    
    my $amount = '';
    
    if( exists $cash_flow->{$date}->{$column_name} ) {
      push( @amounts, $cash_flow->{$date}->{$column_name} );
    } else {
      push( @amounts, '');
    }
    
    $cf->{$date} = [ @amounts ];
     
  }

}

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

# main:
print "date,CASH FLOW,SUM ON DATE," . join( ",", @order) . "\n";

foreach my $date ( sort keys %{$cf} ) {
  
  my @amounts = @{$cf->{$date}};
  my $columns = scalar @amounts;
  
  print "$date,,," . join( ",", @amounts) . "\n";
#  print join(' ', map int2latin($_), $columns+3), "\n";
  
}


#exit;

sub get_definitions {
  
  # String is to be used with DateTime module
  
  $definitions->{yearly}->{string}            = 'years => 1';
  $definitions->{yearly}->{cycles_per_year}   = 1;

  $definitions->{biennial}->{string}          = 'years => 2';
  $definitions->{biennial}->{cycles_per_year} = 0.5;
  
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

