#!/bin/sh

usage() {
    echo "Usage: $0 database_name"
    exit 1
}

if [ $# -ne 1 ]; then
    usage
else 
  bundle install

  DATABASE=$1
  
  dropdb $DATABASE
  createdb $DATABASE
  
  psql -d $DATABASE -f db/schema_no_data.sql
  psql -d $DATABASE -f db/seed_data.sql
fi

