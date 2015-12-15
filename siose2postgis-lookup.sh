#!/bin/bash

echo -e "\n=================================="
echo -e "\nsiose2postgis-lookup"
echo -e "\n=================================="
echo -e "\nImport SIOSE lookup tables from a SIOSE ZIP archive."
echo "Use this tool to read the MDB file in a SIOSE archive."
echo "Data from T_SIOSE_COBERTURAS and T_SIOSE_ATRIBUTOS tables"
echo "will be merged in corresponding replicated tables of the"
echo "given PostgreSQL database using mdbtools."

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

SHORT=s:p:D:U:P:S:C:A:h
LONG=server:,port:,database:,user:,password:,schema:,coverages-lut:,attrs-lut:,help

PARSED=`getopt --options $SHORT --longoptions $LONG --name "$0" -- "$@"`
if [[ $? != 0 ]]; then
    exit 2
fi
eval set -- "$PARSED"
s="localhost"
p="5432"
S="public"
C="siose_coverages"
A="siose_attributes"
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
    -C|--coverages-lut)
      C="$2"
      shift 2
      ;;
    -A|--attrs-lut)
      A="$2"
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
  echo -e "\nUsage: siose2postgis-values.sh [OPTION]... ZIP_ARCHIVE"
  echo -e "\nOptions:"
  echo "  -s,--server[=ADDRESS]            PostgreSQL server address (default is "
  echo "                                  'localhost')"
  echo "  -p,--port[=PORT]                 PostgreSQL server port (default is '5432')"
  echo "  -D,--database[=DBNAME]           Database name (required)"
  echo "  -U,--user[=USERNAME]             PostgreSQL user name (required)"
  echo "  -P,--password[=PASSWORD]         PostgreSQL user password (required)"
  echo "  -S,--schema[=SCHEMANAME]         Database target schema (default is 'public')"
  echo "  -C,--coverages-lut[=TABLENAME]   Target lookup table name for coverages which"
  echo "                                   data from T_SIOSE_COBERTURAS will be merged"
  echo "                                   in (default is 'siose_coverages')"
  echo "  -A,--attrs-lut[=TABLENAME]       Target lookup table name for atributes which"
  echo "                                   data from T_SIOSE_COBERTURAS will be merged"
  echo "                                   in (default is 'siose_attributes')"
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
ZIP_ARCHIVE=$1
echo -e "\nReading $ZIP_ARCHIVE"
#load_start=$(date +'%s')
fuse_folder=`mktemp -d --tmpdir .siose2postgis-XXX`
echo "Mounting $filename to $fuse_folder"
fuse-zip -r $ZIP_ARCHIVE $fuse_folder
for folder in $fuse_folder/*/; do
  for mdbfile in $folder/*.mdb; do
    echo "Reading $mdbfile"
    echo "Loading table T_SIOSE_COBERTURAS"
    load_start=$(date +'%s')
    mdb-schema -T T_SIOSE_COBERTURAS -N $S --no-indexes --no-relations $mdbfile postgres | PGPASSWORD=$P psql -h $s -p $p -d $D -U $U -w --quiet
    mdb-export -I postgres -N $S -b strip -q \' $mdbfile T_SIOSE_COBERTURAS | PGPASSWORD=$P psql -h $s -p $p -d $D -U $U -w --quiet
    echo "Elapsed time: $(($(date +'%s') - $load_start)) secs"
    echo "Loading table T_SIOSE_ATRIBUTOS"
    load_start=$(date +'%s')
    mdb-schema -T T_SIOSE_ATRIBUTOS -N $S --no-indexes --no-relations $mdbfile postgres | PGPASSWORD=$P psql -h $s -p $p -d $D -U $U -w --quiet
    mdb-export -I postgres -N $S -b strip -q \' $mdbfile T_SIOSE_ATRIBUTOS | PGPASSWORD=$P psql -h $s -p $p -d $D -U $U -w --quiet
    echo "Elapsed time: $(($(date +'%s') - $load_start)) secs"
  done
done
fusermount -zu $fuse_folder
echo "Unmounted $fuse_folder"

PGPASSWORD=$P psql -h $s -p $p -d $D -U $U -w -c "ALTER TABLE IF EXISTS $S.\"T_SIOSE_COBERTURAS\" RENAME TO $C" --quiet
echo -e "\nVacuuming table $S.$C"
PGPASSWORD=$P psql -h $s -p $p -d $D -U $U -w -c "VACUUM ANALYZE $S.$C" --quiet

PGPASSWORD=$P psql -h $s -p $p -d $D -U $U -w -c "ALTER TABLE IF EXISTS $S.\"T_SIOSE_ATRIBUTOS\" RENAME TO $A" --quiet
echo -e "\nVacuuming table $S.$A"
PGPASSWORD=$P psql -h $s -p $p -d $D -U $U -w -c "VACUUM ANALYZE $S.$A" --quiet

echo -e "Total elapsed time: $(($(date +'%s') - $START)) secs"
