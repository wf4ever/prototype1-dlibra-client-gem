SPEC_DIR = File.dirname(__FILE__)
lib_path = File.expand_path("#{SPEC_DIR}/../lib")
$LOAD_PATH.unshift lib_path unless $LOAD_PATH.include?(lib_path)

require 'dlibra_client'
require 'uuidtools'

# TODO: Move to config
BASE="http://ivy.man.poznan.pl/rosrs3/"
ADMIN="wfadmin"
ADMIN_PW="wfadmin!!!"
