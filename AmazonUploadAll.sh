#!/bin/sh
export time=$1;
export link=$2

if [ -z "${time}" ];
then export time="30";
fi;

if [ -z "${link}" ];
then export link=`pwd -P`;
fi;

if [ -z "${TMPDIR}" ];
then echo "Error: Please run this program thru the queueing system!";
exit 1;
fi;

export THREADS=`grep -c ^processor /proc/cpuinfo`;
THREADSPLIT=$[ THREADS / 2 ];

cd ${link};
file=`pwd -P | cut -f5,6 -d "/" | tr "/" "."`;
for i in `ls`; do echo "md5sum ${i}/processed/* | sed -e \"s:${i}\/processed\/::g\" > ${i}/processed/${i}.MD5Sum.txt && md5sum ${i}/raw_data/* | sed -e \"s:${i}\/raw_data\/::g\"> ${i}/raw_data/${i}.MD5Sum.txt && md5sum ${i}/Results/* | sed -e \"s:${i}\/Results\/::g\" > ${i}/Results/${i}.MD5Sum.txt;"; done | parallel -j ${THREADS};
md5sum ${link}/../Results/* | sed -e "s:`echo ${link}/../Results/`::g" > ${link}/../Results/${fil}.Results.MD5Sum.txt;
zip -r -0 ${TMPDIR}/${file}.zip */processed */raw_data */Results ${link}/../Results && md5sum ${TMPDIR}/${file}.zip | sed -e "s:${TMPDIR}\/::g" > ${TMPDIR}/${file}.MD5Sum.txt && aws s3 mv ${TMPDIR}/${file}.zip s3://jplab/share/${time}d/;
if [ $? -ne 0 ];
then echo -e "${file} failed to upload to S3, please check error logs for the reason why." | mail -s "${file} Upload Failure" ${USER}@bcm.edu;
else link=`aws s3 presign s3://jplab/share/${time}d/${file}.zip --expires-in $[time * 24 * 60 * 60]`;
echo ${link};
cat ${TMPDIR}/${file}.MD5Sum.txt;
echo -e "${file} successfully uploaded to the Amazon Cloud.  Attached is the MD5Sum, link below:\n${link}" | mail -a ${TMPDIR}/${file}.MD5Sum.txt -s "${file} Upload Complete" ${USER}@bcm.edu;
fi;
exit 0;
