#!/usr/bin/perl -W

use strict;

my $i;
my $fname;
my $count = $#ARGV;
my @body;
my @header;
my $line;
my $head;
my $first;
my $address;
my $line2;
my @items;
my $item;

$first = 0;
for ($i=0; $i<=$count; $i++) {
  $fname = $ARGV[$i];
  $head="";
  open INFILE,"<$fname";
  while (<INFILE>) {
    chomp;
    if (/:8/) {
      $line = substr $_,6;
      if ($head eq "") {
        $head = $line;
        }
      else {
        $head = $head . " " . $line;
        }
      }
    else {
      push @body, $_;
      }
    }
  if ($i != $count) {
    $head =~ s/ 00 *$//;
    }
  else {
    $head =~ s/^c0 .. .. //;
    }
  $first = 1;
  push @header, $head;
  close INFILE;
  }

$address = "8000";
$line2 = ":$address";
$address += 10;
foreach $line (@header) {
  @items = split / /,$line;
  foreach $item (@items) {
    $item =~ s/^ *//;
    $item =~ s/ *$//;
    $line2 = $line2 . " " . $item;
    if (length($line2) > 52) {
      print "$line2\n";
      $line2 = ":$address";
      $address += 10;
      }
    }
  }
print "$line2\n";

foreach $line (@body) {
  print "$line\n";
  }

