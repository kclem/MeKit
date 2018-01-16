my @qCommands = ();
#push @qCommands, "~/bin/qsubGCC49 perl defineRegions.pl both.bed.fisher 10 8 .5";
#push @qCommands, "~/bin/qsubGCC49 perl defineRegions.pl both.bed.fisher 10 8 -.5";
#push @qCommands, "~/bin/qsubGCC49 perl defineRegions.pl both.bed.fisher 10 8 .2";
#push @qCommands, "~/bin/qsubGCC49 perl defineRegions.pl both.bed.fisher 10 8 -.2";
#push @qCommands, "~/bin/qsubGCC49 perl defineRegions.pl both.bed.fisher 10 8 .3";
#push @qCommands, "~/bin/qsubGCC49 perl defineRegions.pl both.bed.fisher 10 8 -.3";
#push @qCommands, "~/bin/qsubGCC49 perl defineRegions.pl both.bed.fisher 10 5 .5";
#push @qCommands, "~/bin/qsubGCC49 perl defineRegions.pl both.bed.fisher 10 5 .2";
#push @qCommands, "~/bin/qsubGCC49 perl defineRegions.pl both.bed.fisher 5 3 .5";
#push @qCommands, "~/bin/qsubGCC49 perl defineRegions.pl both.bed.fisher 5 3 .2";
push @qCommands, "~/bin/qsubGCC49 perl defineRegions.pl both.bed.fisher 5 4 .5";
push @qCommands, "~/bin/qsubGCC49 perl defineRegions.pl both.bed.fisher 5 4 -.5";


die "No commands\n" if (@qCommands == 0);
my $scriptName = $0;
my $qCommandsFile = "$scriptName.commands.txt";
my $qCommandFile = "$scriptName.run.sh";

open QPARAMS, ">$qCommandsFile" or die $!;
print QPARAMS join "\n", @qCommands;
close QPARAMS;

open QCMD, ">$qCommandFile" or die $!;
my $cmdCount = @qCommands;
print QCMD "#!/bin/bash
#\$ -q short
#\$ -l m_mem_free=4g
#\$ -b y
#\$ -V
#\$ -cwd
#\$ -o $qCommandFile.out
#\$ -e $qCommandFile.err
#\$ -t 1-$cmdCount

PARAMFILE=$qCommandsFile
LINE=\$(awk \"NR==\$SGE_TASK_ID\" \$PARAMFILE)
eval \$LINE";
close QCMD;
print `chmod +x $qCommandFile`;

die "\n$cmdCount commands printed. Run\nqsub ./$qCommandFile\n";
