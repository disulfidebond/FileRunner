# simple watcher script
while true ; do
  bash scanDir_fastq.automated.sh
  if [ $? -eq 0 ] ; then
    bash createAndRun_AP_Mu2TO.sh
    while true ; do
      echo 'waiting for analysis to complete'
      if [ -f mu2to_run_completed ] ; then
        sleep 10
        rm mu2to_run_completed
        break
      fi
      sleep 24h
    done
  else 
    echo 'no fastq files found'
  fi
  sleep 30m
done
