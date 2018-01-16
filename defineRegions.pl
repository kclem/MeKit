#defines regions by sliding a sliding window of size $windowSize (number of CpGs). If the average number of significant CpGs is > $minSigCount, the window is added to the region.
use strict;

my $file = shift;
my $windowSize = shift || 5;#number of things to remember
my $minSigCount = shift || 3;
my $diffCutoff = shift || 0.5;
my $pvalCutoff = shift || 0.01;
my $resetDistance = 1000; #reset if cpgs are this far apart

if ($file =~ /\.gz$/)
{
	open(IN, "gunzip -c $file |") or die "can't open pipe to file $file";
}
else
{
	open IN, $file or die "Could not open file $file\n";
}
my $head = <IN>;

my @windowStarts = (0) x $windowSize;
my @windowVals = (0) x $windowSize;
my $root = "$file.w$windowSize.s$minSigCount.d$diffCutoff.p$pvalCutoff";
open OUT, ">$root.reg.unsorted";
open UNMERGED, ">$root.unmerged";

my $totalCpGs = 0;

my @regs = ();
my $thisLine = 0;
my $thisIndex = 0;
my $goodRegStart = 0;
my $inGoodReg = 0;
my $printedPeaks = 0;
my $lastChr = 0;
my $lastStart = 0;
while (my $line = <IN>)
{
	$totalCpGs++;
	chomp $line;
	my @lineEls = split "\t", $line;
	my $chr = $lineEls[0];
	next if $chr eq "chrX";
	next if $chr eq "chrY";
	my $start = $lineEls[1];
	my $pval = $lineEls[4];
	my $diff = $lineEls[5];

	#if we're on a new chromosome or if we are too far away from previous start
	if ($start < $lastStart || $start - $lastStart > $resetDistance)
	{
		printValidRegs();
	}


	$windowStarts[$thisIndex] = $start;
	my $val = 0;
	if ($pval <= $pvalCutoff)
	{
		if ($diffCutoff > 0 && $diff >= $diffCutoff)
		{
			$val = 1;
		}
		elsif ($diffCutoff < 0 && $diff <= $diffCutoff)
		{
			$val = 1;
		}
	}
	$windowVals[$thisIndex] = $val;
	my $countGood = sum(@windowVals);

#	print "stp: $chr\t$start\tp:$pval\td:$diff\t@windowVals\tc:$countGood\n";

	if (!$inGoodReg && $countGood >= $minSigCount)
	{
		$goodRegStart = 0;
		for (my $i = $thisIndex+1; $i < $thisIndex + $windowSize; $i++)
		{
#			print "tI: $thisIndex Checking $i & $windowSize ($windowVals[$i % $windowSize]) == 1)\n";
			if ($windowVals[$i % $windowSize] == 1)
			{
				$goodRegStart = $windowStarts[$i % $windowSize];
#				print "set good start to $goodRegStart\n";
				last;
			}
		}
		#if the whole window has not been covered, the last good start will be 0
		if ($goodRegStart > 0)
		{
			$inGoodReg = 1;
		}
#		print "lws: @windowStarts\nlwc: @windowVals\nlastGoodStart: $goodRegStart\n";
	}
	elsif ($inGoodReg && $countGood < $minSigCount)
	{
		my $goodRegEnd = 0;
		for (my $i = ($thisIndex-1) + $windowSize; $i > $thisIndex; $i--)
		{
			if ($windowVals[$i % $windowSize] == 1)
			{
				$goodRegEnd = $windowStarts[$i % $windowSize];
				last;
			}
		}
		print UNMERGED "$chr\t$goodRegStart\t$goodRegEnd\n";
		push @regs, "$chr\t$goodRegStart\t$goodRegEnd";
		$inGoodReg = 0;
	}

	$lastChr = $chr;
	$lastStart = $start;
	$thisIndex++;
	$thisIndex = 0 if $thisIndex == $windowSize;
	$thisLine++;
}
#print from last chr
printValidRegs();

print `sort -k 1,1 -k2,2n $root.reg.unsorted > $root.reg`;
print `rm $root.reg.unsorted`;

print "read $totalCpGs total CpGs\n";
print "printed $printedPeaks peaks\n";

sub mean 
{
	my $sum = 0;
	for (my $i = 0; $i < $windowSize; $i++)
	{
		$sum += $_[$i];
	}
	return 0 if $sum == 0;
	return $sum/@_;
}

sub median
{
    my @vals = sort {$a <=> $b} @_;
    my $len = @vals;
    if($len%2) #odd?
    {
        return $vals[int($len/2)];
    }
    else #even
    {
        return ($vals[int($len/2)-1] + $vals[int($len/2)])/2;
    }
}
sub sum
{
	my $sum = 0;
	for (my $i = 0; $i < $windowSize; $i++)
	{
		$sum += $_[$i];
	}
	return $sum;

}

sub printValidRegs
{
#	print "printing regs\n===".join("\n",@regs)."\n===\n";
	#add last region if above cutoff
	my $countGood = sum(@windowVals);
	if ($inGoodReg && $countGood >= $minSigCount)
	{
		print UNMERGED "$lastChr\t$goodRegStart\t$lastStart\n";
		push @regs, "$lastChr\t$goodRegStart\t$lastStart";
	}

	#print overlapped regions
	while (@regs)
	{
		#for each region, either print it or merge it with the next one
		my $currReg = shift @regs;
		#if there is a next region
		if (@regs)
		{
			my $nextReg = @regs[0];
			my ($currRegChr,$currRegStart,$currRegEnd) = split "\t", $currReg;
			my ($nextRegChr,$nextRegStart,$nextRegEnd) = split "\t", $nextReg;
			if ($currRegEnd >= $nextRegStart)
			{
				my $newNext = "$nextRegChr\t$currRegStart\t$nextRegEnd";
				$regs[0] = $newNext;
#					print "cre: $currRegEnd < nre $nextRegStart\n";
			}
			else
			{
				print OUT "$currReg\n";
				$printedPeaks++;
			}
		}
		else
		{
			print OUT "$currReg\n";
			$printedPeaks++;
		}
	}
	@regs = ();

	$inGoodReg = 0;
	@windowStarts = (0) x $windowSize;
	@windowVals = (0) x $windowSize;
}
