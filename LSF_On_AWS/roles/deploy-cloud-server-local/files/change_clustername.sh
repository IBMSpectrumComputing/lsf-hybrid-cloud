#!/bin/bash
#-----------------------------------
# Copyright IBM Corp. 1992, 2017. All rights reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#-----------------------------------

exitWithErr ()
{
   echo $* >&2
   exit 1

}
get_prev_cname()
{

  local cname=`sed -n -e '/Begin Cluster/,/End Cluster/ {/Begin Cluster/b;/ClusterName/b;/End Cluster/b;s/^\([^#].*\)/\1/p  }' /opt/ibm/lsfsuite/lsf/conf/lsf.shared`
  echo ${cname}
}

change_path_name()
{

   local file=$1
   if [ -f $file ]; then

       sed -i -e 's@^\(.*/opt/ibm/lsfsuite/lsf/conf/ego/\)[^/].*\(/eservice.*\)@\1'"${curr_cname}\2@" $file
       sed -i -e 's@^\(.*/opt/ibm/lsfsuite/lsf/conf/ego/\)[^/].*\(/kernel.*\)@\1'"${curr_cname}\2@" $file
       sed -i -e 's@^\(.*${EGO_TOP}/conf/ego/\)[^/].*\(/eservice.*\)@\1'"${curr_cname}\2@" $file
       sed -i -e 's@^\(.*/opt/ibm/lsfsuite/lsf/work/\)[^/].*\(/ego.*\)@\1'"${curr_cname}\2@" $file
       sed -i -e 's@^\(.*/opt/ibm/lsfsuite/lsf/work/\)[^/].*\(/live_confdir.*\)@\1'"${curr_cname}\2@" $file
       sed -i -e 's@^\(.*/opt/ibm/lsfsuite/lsf/work/\)[^/].*\(/staging.*\)@\1'"${curr_cname}\2@" $file
   fi
}

change_ego_subdir()
{

   local dir=${LSF_TOPDIR}/conf/ego
   if [ -f ${dir}/${curr_cname} ]; then
       :
   elif [ -f ${dir}/${prev_cname} ]; then
       mv -f ${dir}/${prev_cname} ${dir}/${curr_cname}
   else
       local subdirs=`ls ${dir}`
       for d in ${subdirs}; do
           if [ -d ${dir}/${d}/kernel ]; then
               mv -f ${dir}/${d} ${dir}/${curr_cname}
               break
           fi
        done
   fi
}

change_lsbatch_subdir()
{

   local dir=${LSF_TOPDIR}/conf/lsbatch
   if [ -d ${dir}/${curr_cname} ]; then
       :
   elif [ -d ${dir}/${prev_cname} ]; then
       mv -f ${dir}/${prev_cname} ${dir}/${curr_cname}
   else
       local subdirs=`ls ${dir}`
       for d in ${subdirs}; do
           if [ -d ${dir}/${d}/configdir ]; then
               mv -f ${dir}/${d} ${dir}/${curr_cname}
               break
           fi
       done
   fi
   # PAC doesn't like multiple cluster names under /opt/ibm/lsfsuite/lsf/conf/lsbatch/
   local subdirs=`ls ${dir}`
   for d in ${subdirs}; do
       if [ -d ${dir}/${d} -a "${d}" != "${curr_cname}" ]; then
   	   rm -rf ${dir}/${d} 
       fi
   done

}

change_work_subdir()
{

   # live_confdir/lsbatch/
   local dir=${LSF_TOPDIR}/work/${curr_cname}/live_confdir/lsbatch/
   if [ -d ${dir}/${curr_cname} ]; then
       :
   elif [ -d ${dir}/${prev_cname} ]; then
       mv -f ${dir}/${prev_cname} ${dir}/${curr_cname}
   else
       local subdirs=`ls ${dir}`
       for d in ${subdirs}; do
           if [ -d ${dir}/${d} ]; then
               mv -f ${dir}/${d} ${dir}/${curr_cname}
               break
           fi
        done
   fi

   local dir=${LSF_TOPDIR}/work
   if [ -f ${dir}/${curr_cname} ]; then
       :
   elif [ -f ${dir}/${prev_cname} ]; then
       mv -f ${dir}/${prev_cname} ${dir}/${curr_cname}
   else
       local subdirs=`ls ${dir}`
       for d in ${subdirs}; do
           if [ -d ${dir}/${d}/logdir ]; then
               mv -f ${dir}/${d} ${dir}/${curr_cname}
               break
           fi
       done
   fi
}

# this should be done before change lsf.shared
change_conf_file_names()
{
   local dir=${LSF_TOPDIR}/conf
   # lsf.datamanager file
   if [ -f ${dir}/lsf.datamanager.${curr_cname} ]; then
       :
   elif [ -f ${dir}/lsf.datamanager.${prev_cname} ]; then
       mv -f ${dir}/lsf.datamanager.${prev_cname} ${dir}/lsf.datamanager.${curr_cname}
   else
       for f in `ls ${dir}/lsf.datamanager.*`; do
           mv -f ${dir}/$(basename ${f}) ${dir}/lsf.datamanager.${curr_cname}
           break
       done
   fi
   # lsf.cluster file
   if [ -f ${dir}/lsf.cluster.${curr_cname} ]; then
       :
   elif [ -f ${dir}/lsf.cluster.${prev_cname} ]; then
       mv -f ${dir}/lsf.cluster.${prev_cname} ${dir}/lsf.cluster.${curr_cname}
   else
       for f in `ls $dir/lsf.cluster.*`; do
           mv -f ${dir}/$(basename ${f}) ${dir}/lsf.cluster.${curr_cname}
           break
       done
   fi

}

change_content_path()
{
   local files="\
   ${LSF_TOPDIR}/conf/profile.lsf \
   ${LSF_TOPDIR}/conf/cshrc.lsf \
   ${LSF_TOPDIR}/conf/ego/${curr_cname}/eservice/esc/conf/services/named.xml \
   ${LSF_TOPDIR}/conf/ego/${curr_cname}/eservice/esd/conf/named/conf/named.conf \
   ${LSF_TOPDIR}/conf/ego/${curr_cname}/kernel/ego.conf \
   ${LSF_TOPDIR}/conf/lsf.conf \
   ${LSF_TOPDIR}/conf/lsf.datamanager.${curr_cname} \
   "
   
   for f in $files; do
       if [ -f $f ]; then
          change_path_name ${f}
       fi
   done;
}

change_content_name()
{
   
   # lsf.licensescheduler
   local lsf_licensescheduler_file=${LSF_TOPDIR}/conf/lsf.licensescheduler
   sed -i -e "s/\(CLUSTER_DISTRIBUTION=LanServer(\)[^ ].*\( .*\)/\1${curr_cname}\2/" ${lsf_licensescheduler_file}
   #sed -i -e "/Begin Clusters/,/End Clusters/ {/Begin Clusters/b;/^CLUSTERS/b;/End Clusters/b;s/^[^#].*/${curr_cname}/  }" ${lsf_licensescheduler_file}

   if [ "${prev_cname}" = "myCluster" ]; then
       sed -i -e "/Begin Clusters/,/End Clusters/ {/Begin Clusters/b;/^CLUSTERS/b;/End Clusters/b; s/^[ \t]*\(${prev_cname}.*\)/#\1/  }" ${lsf_licensescheduler_file}
   else
       sed -i -e "/Begin Clusters/,/End Clusters/ {/Begin Clusters/b;/^CLUSTERS/b;/End Clusters/b; /^[ \t]*\(${prev_cname}.*\)/ d;  }" ${lsf_licensescheduler_file}
   fi
   local hasOne=`sed -n -e "/Begin Clusters/,/End Clusters/ { /${curr_cname}/ p}" ${lsf_licensescheduler_file}`
   if [ "x${hasOne}" = "x" ]; then
      sed -i -e "/End Clusters/ i\
${curr_cname}" ${lsf_licensescheduler_file}
   fi

   # lsf.shared
   sed -i -e "/Begin Cluster/,/End Cluster/ {/Begin Cluster/b;/^ClusterName/b;/End Cluster/b;s/^[^#].*/${curr_cname}/  }" ${LSF_TOPDIR}/conf/lsf.shared
   # lsf.datamanager
   if [ -f ${LSF_TOPDIR}/conf/lsf.datamanager.${curr_cname} ]; then
       sed -i -e "/Begin RemoteDataManagers/,/End RemoteDataManagers/ {/Begin RemoteDataManagers/b; /End RemoteDataManagers/b; /CLUSTERNAME/ b;/^#/b; s/^[^ ].*\([ ]\+[^ ].*\)\( .*\)/${curr_cname}\1\2/ }"  ${LSF_TOPDIR}/conf/lsf.datamanager.${curr_cname}
   fi
}

change_cluster_name_datamgr_only()
{
   local dir=${LSF_TOPDIR}/conf
   # lsf.datamanager file
   if [ -f ${dir}/lsf.datamanager.${curr_cname} ]; then
       :
   elif [ -f ${dir}/lsf.datamanager.${prev_cname} ]; then
       mv -f ${dir}/lsf.datamanager.${prev_cname} ${dir}/lsf.datamanager.${curr_cname}
   else
       for f in `ls ${dir}/lsf.datamanager.*`; do
           mv -f ${dir}/$(basename ${f}) ${dir}/lsf.datamanager.${curr_cname}
           break
       done
   fi
   change_path_name  ${LSF_TOPDIR}/conf/lsf.datamanager.${curr_cname}
   if [ -f ${LSF_TOPDIR}/conf/lsf.datamanager.${curr_cname} ]; then
       sed -i -e "/Begin RemoteDataManagers/,/End RemoteDataManagers/ {/Begin RemoteDataManagers/b; /End RemoteDataManagers/b; /CLUSTERNAME/ b;/^#/b; s/^[^ ].*\([ ]\+[^ ].*\)\( .*\)/${curr_cname}\1\2/ }"  ${LSF_TOPDIR}/conf/lsf.datamanager.${curr_cname}
   fi
   # staging dir 
   if [ ! -d  ${LSF_TOPDIR}/work/${curr_cname}/staging ]; then
       pushd ${LSF_TOPDIR}/work > /dev/null 2>&1
       for d in myCluster ${prev_cname}; do
           if [ -d ${d}/staging ]; then
               mv -f ${d}/staging ${curr_cname}
               break
           fi
       done
   popd > /dev/null 2>&1
   fi
   rm -f ${LSF_TOPDIR}/conf/.lsf.datamanager.clustername.${prev_cname}.changed
   touch ${LSF_TOPDIR}/conf/.lsf.datamanager.clustername.${curr_cname}.changed

}

curr_cname=
datamgr_only=N
LSF_TOPDIR=/opt/ibm/lsfsuite/lsf
prev_cname=$(get_prev_cname)
if [ "x${prev_cname}" = "x" ]; then
    exitWithErr "The cluster name cannot be found in lsf.shared."
fi
if [ $# -gt 1 ]; then
    while [[ $# -gt 1 ]]; do
        key="$1"
        case $key in
            -c)
            curr_cname="$2"
            shift
            ;;
            -d)
            datamgr_only="$2"
            shift
            ;;
            *)
            shift
            ;;
        esac
        shift
    done
fi

if [ "x${curr_cname}" = "x" ]; then
    exitWithErr "-c <curr_cname> not specified."
fi
echo "curr_cname = $curr_cname"
if [ "${datamgr_only}" = "Y" ]; then
   echo "change cluster name for DataManager"
   change_cluster_name_datamgr_only
   exit 0
fi

change_lsbatch_subdir
change_work_subdir
change_ego_subdir
change_conf_file_names
change_content_path
change_content_name
rm -f ${LSF_TOPDIR}/conf/.clustername.${prev_cname}.changed
touch ${LSF_TOPDIR}/conf/.clustername.${curr_cname}.changed


