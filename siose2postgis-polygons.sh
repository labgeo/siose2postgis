#!/bin/bash

echo -e "\n=================================="
echo -e "\nsiose2postgis-polygons"
echo -e "\n=================================="
echo -e "\nBatch import a set of SIOSE ZIP archives inside a target directory."
echo "Use this tool to read ESRI Shapefiles in every SIOSE archive."
echo "Polygon data will be merged in a PostGIS table of the given"
echo "PostgreSQL database using OGR."

echo -e "\nThis tool depends on fuse-zip, GDAL and psql. Run:"
echo -e "\n$ apt-get install fuse-zip gdal-bin postgresql-client"
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

SHORT=s:p:D:U:P:S:C:T:h
LONG=server:,port:,database:,user:,password:,schema:,coordsys:,tablename:,help

PARSED=`getopt --options $SHORT --longoptions $LONG --name "$0" -- "$@"`
if [[ $? != 0 ]]; then
    exit 2
fi
eval set -- "$PARSED"
s="localhost"
p="5432"
S="public"
C="4326"
T="siose_polygons"
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
    -C|--coordsys)
      C="$2"
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
  echo -e "\nUsage: siose2postgis-polygons.sh [OPTION]... ARCHIVES_DIRECTORY"
  echo -e "\nOptions:"
  echo "  -s,--server[=ADDRESS]            PostgreSQL server address (default is "
  echo "                                  'localhost')"
  echo "  -p,--port[=PORT]                 PostgreSQL server port (default is '5432')"
  echo "  -D,--database[=DBNAME]           Database name (required)"
  echo "  -U,--user[=USERNAME]             PostgreSQL user name (required)"
  echo "  -P,--password[=PASSWORD]         PostgreSQL user password (required)"
  echo "  -S,--schema[=SCHEMANAME]         Database target schema (default is 'public')"
  echo "  -C,--coordsys[=SRS]              Target coord system EPSG identifier geometry "
  echo "                                   wil be transformed to (default is 4326)"
  echo "  -T,--tablename[=TABLENAME]       Target table name data will be merged in "
  echo "                                   (default is 'siose_polygons')"
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
    for shapefile in $folder/*.shp; do
      echo "Reading $shapefile"
      ogr2ogr -update -append -nlt POLYGON -f "PostgreSQL" -t_srs "EPSG:$C" PG:"host=$s port=$p user=$U dbname=$D schemas=$S password=$P" $shapefile -nln "$T"
    done
  done
  fusermount -zu $fuse_folder
  echo "Unmounted $fuse_folder"
  echo "Elapsed time: $(($(date +'%s') - $load_start)) secs"
done
echo -e "\nVacuuming table $S.$T"
PGPASSWORD=$P psql -h $s -p $p -d $D -U $U -w -c "VACUUM ANALYZE $S.$T" --quiet
echo -e "Total elapsed time: $(($(date +'%s') - $START)) secs"
