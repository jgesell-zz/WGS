#!/bin/sh
THREADS=$1;
link=$2;

if [ -z "${THREADS}" ];
then export THREADS=`grep -c ^processor /proc/cpuinfo`;
fi

if [ -z "${link}" ];
then link=`pwd -P`;
else link=`readlink -e ${link}`;
fi;

Project=`echo ${link} | cut -f5,6 -d "/" | tr -s "/" "."`;
directory=`echo ${Project} | tr -s "." "_" | sed -e "s:Batch:Batch_:g"`;
isRerun=0;

mkdir -p ${link}/${directory};
for i in `find ${link}/Samples/*/raw_data/*_sequence.txt.bz2`;
do name=`basename ${i} | sed -e "s:_sequence\.txt\.bz2:\.fastq\.bz2:g" | sed -e "s:^Seres.::g"`;
if [[ ${name} == *"-R_"* ]];
then isRerun=1;
mkdir -p ${link}/${directory}_RR;
name=`echo ${name} | sed -e "s:\-R_:_:g"`;
ln -s ${i} ${link}/${directory}_RR/${name};
else
ln -s ${i} ${link}/${directory}/${name};
fi;
done;
echo -e "Client\tVendor\tRefence Agreement Version\tTransfer Date\tNames of Files Transferred\tFile Size" > ${link}/${directory}/${Project}.Manifest.txt;
for i in `ls ${link}/${directory} | grep -v txt`; do echo "sum=\`md5sum ${link}/${directory}/${i} | cut -f1 -d ' '\`; size=\`du -shL ${link}/${directory}/${i} | cut -f1\`; echo -e \"Seres Therapudic\tDiversigen\tWMS DTA Agreement for study ID SER-262-001 dated 28_APR_2017\t\`date '+%D'\`\t${i}\t\${size}\" >> ${link}/${directory}/${Project}.Manifest.txt & echo -e \"\${sum}\t${i}\" >> ${link}/${directory}/${Project}.MD5Sums.txt;"; done | parallel -j${THREADS} -k;
if [ ${isRerun} -eq 1 ];
then Project=`echo "${Project}_RR"`;
for i in `ls ${link}/${directory}_RR | grep -v txt`; do echo "sum=\`md5sum ${link}/${directory}_RR/${i} | cut -f1 -d ' '\`; size=\`du -shL ${link}/${directory}_RR/${i} | cut -f1\`; echo -e \"Seres Therapudic\tDiversigen\tWMS DTA Agreement for study ID SER-262-001 dated 28_APR_2017\t\`date '+%D'\`\t${i}\t\${size}\" >> ${link}/${directory}_RR/${Project}.Manifest.txt & echo -e \"\${sum}\t${i}\" >> ${link}/${directory}_RR/${Project}.MD5Sums.txt;"; done | parallel -j${THREADS} -k;
fi;
exit 0;
