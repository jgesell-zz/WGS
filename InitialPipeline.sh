#!/bin/sh

umask 002;
mkdir -p ../Logs;
mkdir -p ../Results;

#First, check to see if data is coming from HGSC
if [ -z ../SampleList ];
then echo "/users/gesell/Programs/gitHub/Miscellaneous/grabFromHgscToCmmr.pl ../SampleList" | qsub -l ncpus=16 -q batch -N `pwd -P | cut -f5,6 -d '/' | tr '/' '.'`.Move -d `pwd -P` -V -e ../Logs -o ../Logs > ../jobIDs.temp;
while [ `qstat | grep -f ../jobIDs.temp | wc -l` -gt 0 ];
do sleep 100;
done;
rm ../jobIDs.temp;
fi;

#Next, trim and filter
~gesell/Programs/gitHub/WGS/trimCommandRunNoDerepHumanFilterCMMR.BBDuK.sh > ../jobIDs.temp;
while [ `qstat | grep -f ../jobIDs.temp | wc -l` -gt 0 ];
do sleep 100;
done;
rm ../jobIDs.temp;

#Exit assuming no issues found with previous steps
exit 0;
