#!/usr/bin/perl -w

use strict;
use warnings;
use Data::Dumper;
use DateTime;
use List::Util qw(sum);

my $definitions;
my $initial;
my $input;
my $cash_flow;

my $DATE_EXEC="gdate"; # bad, need to avoid this

$definitions = main::get_definitions();

my @order;

while (<>) {
 
 chomp;
 my $line = $_;
 
 next if( $line =~ /^\s*$|\s*#/);
 next if( $. == 1); # why?
 
 my @line = split(/,/, $line );

 if( scalar @line ne 5 ) {
   die( "ERROR: on line $. [$line] does not have 5 columns, as it should");
 }
 
 my ($type, $amount, $cycle_start, $frequency, $comment ) = split(/,/, $line );

 $input->{$type}->{amount}      = $amount;
 $input->{$type}->{cycle_start} = $cycle_start;
 $input->{$type}->{frequency}   = $frequency;
 $input->{$type}->{comment}     = $comment;
 
 if( ! exists $definitions->{$frequency} ) {
   die("ERROR: line $. [$line] has a frequency of [$frequency] which is not defined");
 }
 $input->{$type}->{cycles}      = $definitions->{$frequency}->{cycles_per_year};
 
 push( @order, $type );
 
}

my @inputs = keys %{$input};
# 
# if( scalar @inputs ne scalar @order ) {
  # die("ERROR: number of inputs does not match the order of columns!");
# }
# 
# foreach my $column_name ( @order ) {
  # if( ! exists $input->{$column_name} ) {
    # die("ERROR: Column name $column_name is not defined!");
  # }
# }

foreach my $type ( sort keys %{$input} ) {
  
  my $cycle_start = $input->{$type}->{cycle_start};
  my $amount      = $input->{$type}->{amount};
  my $frequency   = $definitions->{$input->{$type}->{frequency}}->{string};
  my $cycles      = $input->{$type}->{cycles};
  
  my $d = $cycle_start;
  $cash_flow->{$d}->{$type}=$amount;
   
  for (my $n=0; $n <= $cycles-1; $n++) {
   my $dd = "-d $d $frequency";
   $d=`$DATE_EXEC '+%Y-%m-%d' "$dd"`;
   $d =~ s/\n$//g;
   $cash_flow->{$d}->{$type}=$amount;
  }
  
}

my $cf;

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

print "date,CASH FLOW,SUM ON DATE," . join( ",", @order) . "\n";

foreach my $date ( sort keys %{$cf} ) {
  
  my @amounts = @{$cf->{$date}};
  
#  print sum(0, @amounts);
#  print "\n";
  print "$date,,," . join( ",", @amounts) . "\n";
  
}

sub get_definitions {
  
  $definitions->{yearly}->{string}            = '1 year';
  $definitions->{yearly}->{cycles_per_year}   = 1;

  $definitions->{monthly}->{string}           = '1 month';
  $definitions->{monthly}->{cycles_per_year}  = 12;
  
  $definitions->{biweekly}->{string}          = '2 weeks';
  $definitions->{biweekly}->{cycles_per_year} = 26;
  
  $definitions->{weekly}->{string}            = '1 week';
  $definitions->{weekly}->{cycles_per_year}   = 52;
  
  $definitions->{daily}->{string}             = '1 day';
  $definitions->{daily}->{cycles_per_year}    = 365;
  
  $definitions->{quarterly}->{string}          = '3 months';
  $definitions->{quarterly}->{cycles_per_year} = 4;  

  $definitions->{once}->{string}               = '0 days';
  $definitions->{once}->{cycles_per_year}      = 0;  
  
  return $definitions;

}