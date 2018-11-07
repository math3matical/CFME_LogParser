These scripts are meant to assist in analyzing certain logs from a CloudForms appliance.  These have currently been tested on CloudForms 4.6 (CFME 5.9).  Please use these at your own risk.  Currently the scripts are only reading the log files, so no manipulation of the log files are occuring.  For safest use, please copy the desired logs to a new location, and run these scripts against them.

To run the log_parser.rb script:

  $ ruby log_parster.rb <evm.log>


To run the provision_scan.rb script:

 $ ruby provision_scan.rb <automation.log> <evm.log> <request id>


Please note, the provision_scan.rb can currently take multiple request ids as input.  Currently, use either all service request ids, or all lifecycle request ids (as the script will ask you which type you used, plans are to change this to denote a flag to determine this).  Also, you should be able to cat all of the automation logs in a region together, and same with evm.log.
