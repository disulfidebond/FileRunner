# remove any existing runfiles
rm runFile.data.csv 2> /dev/null
rm runFile.analysis.csv 2> /dev/null


# add extra pause to account for files being copied to directory
sleep 1h

ARR=($(ls . | grep 'fastq.gz$' | cut -d_ -f1 | sort -n | uniq))
ARRCHECK=$(echo ${#ARR[@]})
SUFFIX='fastq.gz$'
if ((ARRCHECK==0)) ; then
  ARR=($(ls . | grep 'fastq$' | cut -d_ -f1 | sort -n | uniq))
  ARRCHECK=$(echo ${#ARR[@]})
  SUFFIX='fastq$'
fi
if ((ARRCHECK==0)) ; then
  ARR=($(ls . | grep 'fq.gz$' | cut -d_ -f1 | sort -n | uniq))
  ARRCHECK=$(echo ${#ARR[@]})
  SUFFIX='fq.gz$'
fi
if ((ARRCHECK==0)) ; then
  ARR=($(ls . | grep 'fq$' | cut -d_ -f1 | sort -n | uniq))
  ARRCHECK=$(echo ${#ARR[@]})
  SUFFIX='fq$'
fi
if ((ARRCHECK==0)) ; then
  echo 'Error, no read files found with endings:'
  echo 'fq, fq.gz. fastq, fastq.gz'
  exit 1
fi

for i in "${ARR[@]}" ; do 
  FARRAY=($(ls . | grep "^${i}" | grep "$SUFFIX"))
  CT=0
  S=''
  for x in "${FARRAY[@]}" ; do
    if ((CT==0)) ; then
      S=$(echo "${x}")
      let CT=$CT+1
    else
      S=$(echo "${S},${x}")
      echo "${S}" >> runFile.data.csv
      let CT=0
    fi
  done
done
