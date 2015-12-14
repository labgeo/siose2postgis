#!/bin/bash

echo -e "\n=================================="
echo -e "\nsiose2postgis-values"
echo -e "\n=================================="
echo -e "\nBatch import a set of SIOSE ZIP archives inside a target directory."
echo "Use this tool to read MDB files in every SIOSE archive."
echo "Data from T_VALORES table will be merged in a replicated table of the given"
echo "PostgreSQL database using mdbtools."

echo -e "\nThis tool depends on fuse-zip, mdbtools and psql. Run:"
echo -e "\n$ apt-get install fuse-zip mdbtools postgresql-client"
echo -e "\nto install these packages on a Debian system."

# Script args are handled using getopt.
# Code based on Robert Siemer's answer to question
# 'How do I parse command line arguments in bash?' on SO
# (see http://stackoverflow.com/a/29754866).
getopt --test > /dev/null
if [[ $? != 4 ]]; then
    echo "`getopt --test` failed in this environment."
    exit 1
fi

SHORT=s:p:D:U:P:S:T:h
LONG=server:,port:,database:,user:,password:,schema:,tablename:,help
DONE_CREATETABLE=false

PARSED=`getopt --options $SHORT --longoptions $LONG --name "$0" -- "$@"`
if [[ $? != 0 ]]; then
    exit 2
fi
eval set -- "$PARSED"
s="localhost"
p="5432"
S="public"
T="siose_values"
while true; do
  case "$1" in
    -s|--server)
      s="$2"
      shift 2
      ;;
    -p|--port)
      p="$2"
      shift 2
      ;;
    -D|--database)
      D="$2"
      shift 2
      ;;
    -U|--user)
      U="$2"
      shift 2
      ;;
    -P|--password)
      P="$2"
      shift 2
      ;;
    -S|--schema)
      S="$2"
      shift 2
      ;;
    -T|--tablename)
      T="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -h|--help)
      h=y
      shift
      break
      ;;
    *)
      echo "Invalid argument $1"
      exit 3
      ;;
    esac
done

# Portable syntax to evaluate if variable is defined and not empty.
# Based on Gilles' answer to question
# 'How to test if a variable is defined at all in Bash?' on StackExchange
# (see http://unix.stackexchange.com/a/56846).
if [ -n "${h:+1}" ]; then
  echo -e "\nUsage: siose2postgis-values.sh [OPTION]... ARCHIVES_DIRECTORY"
  echo -e "\nOptions:"
  echo "  -s,--server[=ADDRESS]            PostgreSQL server address (default is "
  echo "                                  'localhost')"
  echo "  -p,--port[=PORT]                 PostgreSQL server port (default is '5432')"
  echo "  -D,--database[=DBNAME]           Database name (required)"
  echo "  -U,--user[=USERNAME]             PostgreSQL user name (required)"
  echo "  -P,--password[=PASSWORD]         PostgreSQL user password (required)"
  echo "  -S,--schema[=SCHEMANAME]         Database target schema (default is 'public')"
  echo "  -T,--tablename[=TABLENAME]       Target table name which data from T_VALORES"
  echo "                                    will be merged in (default is 'siose_values')"
  echo "  -h,--help                        Show this help and exit"
  exit 4
fi

if [[ $# != 1 ]]; then
    echo -e "\nMISSING ARGUMENT: A single input directory is required."
    exit 5
fi

if ! [ -n "${D:+1}" ]; then
  echo -e "\nMISSING ARGUMENT: Please provide a database name with -D."
  exit 6
fi

if ! [ -n "${U:+1}" ]; then
  echo -e "\nMISSING ARGUMENT: Please provide a user name with -U."
  exit 7
fi

if ! [ -n "${P:+1}" ]; then
  echo -e "\nMISSING ARGUMENT: Please provide a user password with -P."
  exit 8
fi

START=$(date +'%s')
DATA_FOLDER=$1
echo -e "\nReading $DATA_FOLDER"
for filename in $DATA_FOLDER/*.zip; do
  load_start=$(date +'%s')
  fuse_folder=`mktemp -d --tmpdir .siose2postgis-XXX`
  echo "Mounting $filename to $fuse_folder"
  fuse-zip -r $filename $fuse_folder
  for folder in $fuse_folder/*/; do
    for mdbfile in $folder/*.mdb; do
      echo "Reading $mdbfile"
      if [ $DONE_CREATETABLE = false ]; then
        mdb-schema -T T_VALORES -N $S --no-indexes --no-relations $mdbfile postgres | PGPASSWORD=$P psql -h $s -p $p -d $D -U $U -w --quiet
        DONE_CREATETABLE=true
      fi
      mdb-export -I postgres -N $S -b strip -q \' $mdbfile T_VALORES | PGPASSWORD=$P psql -h $s -p $p -d $D -U $U -w --quiet
    done
  done
  fusermount -zu $fuse_folder
  echo "Unmounted $fuse_folder"
  echo "Elapsed time: $(($(date +'%s') - $load_start)) secs"
done
PGPASSWORD=$P psql -h $s -p $p -d $D -U $U -w -c "ALTER TABLE IF EXISTS $S.\"T_VALORES\" RENAME TO $T" --quiet
PGPASSWORD=$P psql -h $s -p $p -d $D -U $U -w -c "ALTER TABLE IF EXISTS $S.\"T_VALORES_ID1_seq\" RENAME TO ${T}_ID1_seq" --quiet
echo -e "\nVacuuming table $S.$T"
PGPASSWORD=$P psql -h $s -p $p -d $D -U $U -w -c "VACUUM ANALYZE $S.$T" --quiet
echo -e "Total elapsed time: $(($(date +'%s') - $START)) secs"
