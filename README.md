MinGW-GDC
=========

 * Lastest working:
   * D2.062 GCC 4.8.0

The procedures in this document are for building using MinGW's msys environment.

The script used to build GDC handles all dependencies and runs the DMD testsuite.

Building
--------

* Install latest version of MinGW, MSYS [[http://mingw.org]]

* Download the latest MinGW-GDC head

	    git clone https://github.com/venix1/MinGW-GDC.git

  * For the 4.8 branch append **-b GDC-4.8**

* Enter directory and run

	    ./build.sh 


For details about how to compile manually, review the [build.sh](https://github.com/venix1/MinGW-GDC/blob/master/build.sh) script 

Common Issues
-------------