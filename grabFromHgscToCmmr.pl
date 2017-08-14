#!/usr/bin/env perl

use warnings;
use strict;
use File::Basename;

my $in = $ARGV[0];
open IN, "$in";
open TEMP, ">Commands.out";

while (my $line = <IN>) {

	chomp $line;
	my @fields = split(/\t/, $line);
	$fields[0] =~ s/\s+//g;
	my $filesToCopy = "";
	$filesToCopy = `ssh sug-login1.hgsc.bcm.edu "ls $fields[1]/*sequence.txt.bz2 2>/dev/null"`;
	my @filelist = split("\n", $filesToCopy);
	unless (scalar(@filelist) == 2) {
		die "$fields[0] doesn't have two files to copy\n";
	}
	push (@filelist, "$fields[1]/ReadsPassingPurityFilter.metrics");
	unless ($filesToCopy) {
		print STDERR "$fields[0] failed copy\n";
		next
	}
	print "file to copy =\n$filesToCopy\n";
	`mkdir -p $fields[0]/raw_data`;
	foreach my $file (@filelist) {
		print "copying $file\n";
		print TEMP  "$file\t$fields[0]/raw_data/\n";
	}
}

close TEMP;
`cat Commands.out | parallel -I {} -j8 'file=\`echo {} | cut -f1\`; source=\`echo \${file} | rev | cut -f1 -d "/" | cut -f1,2 -d "_" | rev\`; dest=\`echo {} | cut -f2\`; rsync -azL sug-login1.hgsc.bcm.edu:\$file \${dest}/\`echo \${dest} | cut -f1 -d "/"\`_\${source}'; mv Commands.out ../; mkdir -p ../Results; echo -n "SampleID:" > ../Results/Stats.txt; for i in \`ls | sort\`; do echo -en esults/Stats.txt; done; echo -en "\nRaw Reads:" >> ../Results/Stats.txt; for i in \`ls\`; do count=\`cat \${i}/raw_data/\${i}_ReadsPassingPurityFilter.metrics | grep -A3 "Read 1" | grep "Total Filtered Reads" | cut -f2 -d ":" | sed -e "s:\\s::g"\`; echo -en "\t\${count}" >> ../Results/Stats.txt; done;`;
