#!/usr/bin/perl -w
use strict;
use File::Path;
use File::Basename;
use Log::Log4perl qw(:easy get_logger);
# Log::Log4perl->easy_init( { level => $INFO, file => 'STDOUT' });
Log::Log4perl->easy_init( { level => $DEBUG, file => 'STDOUT' });

my $log = get_logger();
# my $srcFile = dirname($0) . "/foo.txt";
if ($#ARGV != 1) {
  print "Must supply input and output file paths/names on command line\n";
  exit 1;
}
my $srcFile = $ARGV[0];
my $destFile = $ARGV[1];
print "Getting number of lines in the file $srcFile...";
open FH, "wc $srcFile | awk '{print \$1}' |";
my @nLines = <FH>;
my $nLines = $nLines[0];
$nLines =~ s/\n//g;
print "$nLines lines\n";
close FH;
open (IN, $srcFile);
open (OUT, ">" . $destFile);
my $lineCount = 0;
my $extendedCharCount = 0;
my $twoSeqCount = 0;
my $threeSeqCount = 0;
my $fourSeqCount = 0;
my $htmlEntityCount = 0;
my $iso8859_8bitCount = 0;
my $deprecatedAsciiControlCount = 0;
my %entitiesMap;
my $linecountLogFrequency = 10000;
my $reportingLogFrequency = 100000;
while (<IN>) {
  my $line = $_;
  my @lineArray = split(//, $line);
  $lineCount++;
  $log->info("Processing line $lineCount of $nLines (" . sprintf("%3.1f", ($lineCount/$nLines)*100) . "%)...\n") if ($lineCount % $linecountLogFrequency == 0);
  print reportResults() if ($lineCount % $reportingLogFrequency == 0);
  print entityHashToString() if ($lineCount % $reportingLogFrequency == 0);

  my $isExtended;
  my $lineCopy = $line;
  while ($lineCopy =~ m/&#?x?(\w|\d)+;/g) {
    my $mmatch = $&;
    $htmlEntityCount++;
    if (exists($entitiesMap{$mmatch})) {
      my $r = $entitiesMap{$mmatch};
      $entitiesMap{$mmatch} = sprintf("%d", (atoi($r) + 1));
    }
    else {
      $entitiesMap{$mmatch} = "1";
    }

  }
  for (my $i = 0; $i < @lineArray; $i++) {
    my $c = ord($lineArray[$i]);
    my $incr = 0;
    if (isAscii($c)) {
      if (isDeprecatedAsciiCtrlChar($c)) {
        $deprecatedAsciiControlCount++;
        print "Line $lineCount:  deprecated ascii control character $c\n";
        print OUT "Line $lineCount:  deprecated ascii control character $c\n";
      }
      next;
    }
    if (isExtendedCandidate($c)) {
      $isExtended = 1;
      my $ssize = @lineArray;
      $incr = isTwoSeq(\@lineArray, $i);
      if ($incr > 0) {
          $twoSeqCount++;
          $i += $incr;
          next;
      }
      $incr = isThreeSeq(\@lineArray, $i);
      if ($incr > 0) {
          $threeSeqCount++;
          $i += $incr;
          next;
      }
      $incr = isFourSeq(\@lineArray, $i);
      if ($incr > 0) {
          $fourSeqCount++;
          $i += $incr;
          next;
      }
      if (isISO8859_8bitChar($c)) {
        $iso8859_8bitCount++;
        next;
      }
      $extendedCharCount++;
    }
      

  }
}
print OUT reportResults();
print OUT entityHashToString();
close IN;
# close OUT;
# $log->info($lineCount . " rows cleaned, file written to $destFile.");
sub isISO8859_8bitChar {
  my ($c) = @_;
  return($c > 159 && $c < 256);
}

sub isDeprecatedAsciiCtrlChar {
  my ($c) = @_;
  return(($c > 0 && $c <= 6) || ($c == 11) || ($c > 13 && $c < 27) || ($c > 27 && $c < 32));
}
sub reportResults {
  return("Extended ASCII/WinLatin1: $extendedCharCount\n" .
  "Valid ISO 8859 8-bit characters: $iso8859_8bitCount\n" .
  "Two Byte Sequences: $twoSeqCount\n" .
  "Three Byte Sequences: $threeSeqCount\n" .
  "Four Byte Sequences: $fourSeqCount\n" .
  "HTML entities: $htmlEntityCount\n" .
  "Deprecated ascii control characters:  $deprecatedAsciiControlCount\n");
}
sub entityHashToString {
  my $result = "HTML entities count:\n";
  my $key;
  my $value;
  while(($key, $value) = each(%entitiesMap)) {
    $result .= "[$key]: $value\n";
  }
  return($result);
}
sub isAscii {
  my ($c) = @_;
  return($c < 128);
}
sub isExtendedCandidate {
  my ($c) = @_;
  return($c > 127 && $c <= 0xFF);
}
sub isMultiByteSeqChar {
  my ($c) = @_;
  return ($c > 0x7F && $c < 0xC0);
}
  
sub isTwoSeq {
  my(@lineArray) = @{$_[0]};
  my($i) = $_[1];
  my $ssize = @lineArray;
  my $result = 0;
  if (($i + 1) < $ssize) {
    my $c1 = ord($lineArray[$i]);
    my $c2 = ord($lineArray[$i + 1]);
    if ($c1 >= 0xC2 && $c1 <= 0xDF && isMultiByteSeqChar($c2)) {
      $result = 1;
    }
  }
  return($result);
}
sub isThreeSeq {
  my(@lineArray) = @{$_[0]};
  my($i) = $_[1];
  my $ssize = @lineArray;
  my $result = 0;
  if (($i + 2) < $ssize) {
    my $c1 = ord($lineArray[$i]);
    my $c2 = ord($lineArray[$i + 1]);
    my $c3 = ord($lineArray[$i + 2]);
    if ($c1 >= 0xE0 && $c1 <= 0xEF && isMultiByteSeqChar($c2) && isMultiByteSeqChar($c3)) {
      $result = 2;
    }
  }
  return($result);
}
sub isFourSeq {
  my(@lineArray) = @{$_[0]};
  my($i) = $_[1];
  my $ssize = @lineArray;
  my $result = 0;
  if (($i + 3) < $ssize) {
    my $c1 = ord($lineArray[$i]);
    my $c2 = ord($lineArray[$i + 1]);
    my $c3 = ord($lineArray[$i + 2]);
    my $c4 = ord($lineArray[$i + 3]);
    if ($c1 >= 0xF0 && $c1 <= 0xF4 && isMultiByteSeqChar($c2) && isMultiByteSeqChar($c3) && isMultiByteSeqChar($c4)) {
      $result = 3;
    }
  }
  return($result);
}
sub atoi {
  my $t = 0;
  foreach my $d (split(//, shift())) {
    $t = $t * 10 + $d;
  }
  return $t;
}
