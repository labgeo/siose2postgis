# siose2postgis
Utilities for loading SIOSE data into a PostgreSQL/PostGIS database  
  
SIOSE is the Spanish Government Information System on Land Use, which follows EU's INSPIRE Directive specification on public land use data collection and deployment. These utilities help researchers in bulk loading SIOSE data from ZIP archives served by the Spanish National Center for Geographical Information (CNIG) into a PostgreSQL geodatabase.  
  
## Executing *siose2postgis* utilities
There are 3 bash scripts available for execution in Linux boxes which can be run in any order:  
  
-  `siose2postgis-polygons` Batch import a set of SIOSE ZIP archives inside a target directory. Use this tool to read ESRI Shapefiles in every SIOSE archive. Polygon data will be merged in a PostGIS table of the given PostgreSQL database using OGR.
-  `siose2postgis-values` Batch import a set of SIOSE ZIP archives inside a target directory. Use this tool to read MDB files in every SIOSE archive. Data from T_VALORES table will be merged in a replicated table of the given PostgreSQL database using mdbtools.
-  `siose2postgis-values` Import SIOSE lookup tables from a SIOSE ZIP archive. Use this tool to read the MDB file in a SIOSE archive. Data from TC_SIOSE_COBERTURAS and TC_SIOSE_ATRIBUTOS tables will be merged in corresponding replicated tables of the
given PostgreSQL database using mdbtools.  
  
**Please be warned** that neither of these commands is designed for appending or overwriting purposes. You're suposed to run them once on an empty PostgreSQL database with the PostGIS extension enabled. If loading the whole CNIG SIOSE dataset for a particular campaign, expect `siose2postgis-values` to take several hours to finish processing.  
Invoke any of the 3 commands with `--help` option detailed arguments and usage.

## Software requirements
Please ensure you have installed the following packages before running the scripts:  
  
-  fuse-zip
-  gdal-bin
-  mdbtools
-  postgresql-client  
  
*siose2postgis* utilities have been succesfully tested on PostgreSQL 9.5 and PostGIS 2.1.
