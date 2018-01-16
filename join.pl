use strict;

use Getopt::Long;
my $samplesFile  = "";
my $comboFile = "";
my $leaveIntermediate = 0;
my $zipOutput = 0;
my $print = "0";
GetOptions ("samplesFile=s" => \$samplesFile,
		"comboFile=s" => \$comboFile,
		"leaveIntermediate" => \$leaveIntermediate,
		"zipOutput" => \$zipOutput,
		"print" => \$print,
	)
	or die("Error in command line arguments\n");


$samplesFile = shift @ARGV if $samplesFile eq "";
$samplesFile = "samples.txt" if $samplesFile eq "";
$comboFile = "all.cpg" if $comboFile eq "";

print "params:
samplesFile: $samplesFile
comboFile: $comboFile
zipOutput: $zipOutput
print: $print
";
my $zipString = "";
$zipString = "--zipOutput" if $zipOutput;

if ($print)
{
	#die "qsub -q short -N join -b y -cwd -o join.pl.out -e join.pl.err perl ~/scripts/cpgAnalysis/regions/join.pl -samplesFile $samplesFile -comboFile $comboFile $zipString";
	die "qsub -q broad -l h_vmem=4g -l h_rt=08:00:00 -N join -b y -cwd -o join.pl.out -e join.pl.err perl ~/scripts/cpgAnalysis/regions/join.pl -samplesFile $samplesFile -comboFile $comboFile $zipString";
}

open SAM, $samplesFile or die "Cannot open samples file '$samplesFile'\n$!";
my @sampleList = ();
my %sampleLocs = ();
while (my $line = <SAM>)
{
	chomp $line;
	my ($sample, $loc) = split "\t", $line;
	die "already seen sample $sample" if exists $sampleLocs{$sample};
	$sampleLocs{$sample} = $loc;
	die "bed file does not exist for sample $sample at '$loc'\n" unless -e $loc;
	push @sampleList, $sample;
}

if (!-e $comboFile)
{
	foreach my $sample (@sampleList)
	{
		runCommand("perl ~/scripts/addBedTarget.pl $comboFile $sampleLocs{$sample} 0 $sample");
		if (-e "$comboFile.unfinished")
		{
			die "Unfinished file exists at '$comboFile.unfinished'\n";
		}
	}
}
else #combo file exists
{
	open S, $comboFile or die $!;
	my $head = <S>;
	chomp $head;
	close S;
	my @headEls = split "\t", $head;
	shift @headEls; #chr
	shift @headEls; #start
	for (my $i = 0; $i < @sampleList; $i++)
	{
		my $headEl = $headEls[$i];
		my $sample = $sampleList[$i];
		if ($headEl ne "" && $headEl ne $sample)
		{
			die "mismatch at sample $i: expecting '$sample', got '$headEl'\n";
		}
		elsif ($headEl eq $sample)
		{
			next;
		}
		runCommand("perl ~/scripts/addBedTarget.pl $comboFile $sampleLocs{$sample} 0 $sample");
		if (-e "$comboFile.unfinished")
		{
			die "Unfinished file exists at '$comboFile.unfinished'\n";
		}
	}
}

if (!-e "$comboFile.GT0decimal.na" && !-e "$comboFile.GT0decimal.na.gz")
{
	runCommand("perl ~/scripts/toDecimal.pl $comboFile 0");
	runCommand("perl ~/scripts/filter/filterNAs.pl $comboFile.GT0decimal .2");
	if ($leaveIntermediate)
	{
		if ($zipOutput)
		{
			runCommand("gzip $comboFile.GT0decimal");
			runCommand("gzip $comboFile.GT0decimal.na");
		}
	}
	else
	{
		runCommand("rm $comboFile.GT0decimal");
		if ($zipOutput)
		{
			runCommand("gzip $comboFile.GT0decimal.na");
		}
	}
}
if (!-e "$comboFile.GT4decimal.na" && !-e "$comboFile.GT4decimal.na.gz")
{
	runCommand("perl ~/scripts/toDecimal.pl $comboFile 4");
	runCommand("perl ~/scripts/filter/filterNAs.pl $comboFile.GT4decimal .2");
	if ($leaveIntermediate)
	{
		if ($zipOutput)
		{
			runCommand("gzip $comboFile.GT4decimal");
			runCommand("gzip $comboFile.GT4decimal.na");
		}
	}
	else
	{
		runCommand("rm $comboFile.GT4decimal");
		if ($zipOutput)
		{
			runCommand("gzip $comboFile.GT4decimal.na");
		}
	}
}

runCommand("gzip $comboFile") if $zipOutput;




sub runCommand
{
	my $command = shift;
	my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	$minute = sprintf("%02d",$minute);
	$second = sprintf("%02d",$second);
	print "$hour:$minute:$second\n$command\n";
	print `$command 2>&1`;
	my $exit_value  = $? >> 8;
	my $signal_num  = $? & 127;
	my $dumped_core = $? & 128;
	if ($exit_value)
	{
		print "========\nJob failed\n========\n";
		print "Exit value: $exit_value\n";
		print "Signal num: $signal_num\n";
		print "Dumped core: $dumped_core\n";
		die;
	}
}

