use strict;
use Text::NSP::Measures::2D::Fisher::twotailed;
use Statistics::Distributions qw(chisqrprob);
my $usage = "perl getFisher.pl\n";
my $file = shift;

my %fisherLookup = ();
print "Starting at ".printTime()."\n";

open IN, $file or die $!;
my $header = <IN>;
chomp $header;

my $info = "$file.info";
my $outTemp = "$file.unfinished";
my $out = "$file.fisher";

my $filter = 3;

open OUT, ">$outTemp" or die "Could not open $outTemp for writing\n";
print OUT "$header\tpVal\tdiff\n";


while (my $line = <IN>)
{
	chomp $line;
	my @lineEls = split "\t", $line;
	my $count = $lineEls[15];

	my ($pval,$diff)  = getPvalsMeth($lineEls[2], $lineEls[3]);

	print OUT "$line\t$pval\t$diff\n";
}
print "Finished at ".printTime()."\n";
print `mv $outTemp $out`."\n";

sub getPvalsMeth
{
	my $val1 = shift;
	my $val2 = shift;
	my ($meth1,$seen1) = split "/", $val1;
	my ($meth2,$seen2) = split "/", $val2;
	return getFisher($meth1,$seen1,$meth2,$seen2);

}

sub getFisher
{
	my $f1Meth = shift;
	my $f1Reads = shift;
	my $f2Meth = shift;
	my $f2Reads = shift;
	my $twotailed_value = -1;
	if ($f1Reads >= $filter && $f2Reads >= $filter)
	{
		my $fisherKey = "$f1Meth $f1Reads $f2Meth $f2Reads";
		if (exists $fisherLookup{$fisherKey})
		{
			$twotailed_value = $fisherLookup{$fisherKey};
		}
		else
		{
			#        meth    ~meth
			#  f1    n11      n12 | n1p
			#  f2    n21      n22 | n2p
			#        --------------
			#        np1      np2   npp
			my $npp = $f1Reads + $f2Reads; 
			my $n1p = $f1Reads; 
			my $np1 = $f1Meth + $f2Meth;  
			my $n11 = $f1Meth;

			$twotailed_value = calculateStatistic( n11=>$n11,
				n1p=>$n1p,
				np1=>$np1,
				npp=>$npp);

			if( (my $errorCode = getErrorCode()))
			{
				warn $errorCode." - ".getErrorMessage();
			}
			else
			{
				$fisherLookup{$fisherKey} = $twotailed_value;

			}
		}

		my $f1pct = ($f1Meth/$f1Reads);
		my $f2pct = ($f2Meth/$f2Reads);
		my $diff = ($f1pct) - ($f2pct);
#		print "twotailed: $twotailed_value, $diff\n";
		return ($twotailed_value,$diff);
	}
	return ("NA","NA");
}
sub fisher_chisq_combine 
{

	my $sum = 0;
	my $numTests = 0;
	foreach my $pval (@_)
	{
		next if $pval eq "NA";
		my $logval = ($pval > 0)?log($pval):99**99;
		$sum += $logval;
		$numTests++;
	}
	if ($numTests == 0)
	{
		return "NA";
	}
	my $chisq = -2 * $sum;

	my $dof = 2 * $numTests;

	my $pval = Statistics::Distributions::chisqrprob ($dof, $chisq);

	return $pval;
}

sub mean
{
	my $sum = 0;
	my $count = 0;
	foreach my $val (@_)
	{
		next if $val eq "NA";
		$sum += $val;
		$count++;
	}
	return "NA" if $count == 0;

	return $sum/$count;
}

sub printTime
{
	my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	$minute = sprintf("%02d",$minute);
	$second = sprintf("%02d",$second);
	return "$hour:$minute:$second";
}
