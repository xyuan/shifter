/* Shifter, Copyright (c) 2015, The Regents of the University of California,
## through Lawrence Berkeley National Laboratory (subject to receipt of any
## required approvals from the U.S. Dept. of Energy).  All rights reserved.
## 
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions are met:
##  1. Redistributions of source code must retain the above copyright notice,
##     this list of conditions and the following disclaimer.
##  2. Redistributions in binary form must reproduce the above copyright notice,
##     this list of conditions and the following disclaimer in the documentation
##     and/or other materials provided with the distribution.
##  3. Neither the name of the University of California, Lawrence Berkeley
##     National Laboratory, U.S. Dept. of Energy nor the names of its
##     contributors may be used to endorse or promote products derived from this
##     software without specific prior written permission.
## 
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
## AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
## IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
## ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
## LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
## CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
## SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
## INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
## CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
## ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
## POSSIBILITY OF SUCH DAMAGE.
##  
## You are under no obligation whatsoever to provide any bug fixes, patches, or
## upgrades to the features, functionality or performance of the source code
## ("Enhancements") to anyone; however, if you choose to make your Enhancements
## available either publicly, or directly to Lawrence Berkeley National
## Laboratory, without imposing a separate written license agreement for such
## Enhancements, then you hereby grant the following license: a  non-exclusive,
## royalty-free perpetual license to install, use, modify, prepare derivative
## works, incorporate into other computer software, distribute, and sublicense
## such enhancements or derivative works thereof, in binary and source code
## form.
*/

#ifndef __UDIROOTCONFIG_INCLUDE
#define __UDIROOTCONFIG_INCLUDE

#define _GNU_SOURCE
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define UDIROOT_VAL_CFGFILE 0x01
#define UDIROOT_VAL_PARSE   0x02
#define UDIROOT_VAL_SSH     0x04 
#define UDIROOT_VAL_KMOD    0x08
#define UDIROOT_VAL_ALL 0xffffffff

#ifndef IMAGEGW_PORT_DEFAULT
#define IMAGEGW_PORT_DEFAULT 7777
#endif

typedef struct _ImageGwServer {
    char *server;
    int port;
} ImageGwServer;

typedef struct _UdiRootConfig {
    char *nodeContextPrefix;
    char *udiMountPoint;
    char *loopMountPoint;
    char *batchType;
    char *system;
    char *imageBasePath;
    char *udiRootPath;
    char *sitePreMountHook;
    char *sitePostMountHook;
    char *sshPath;
    char *etcPath;
    char *kmodBasePath;
    char *kmodPath;
    char *kmodCacheFile;
    ImageGwServer **servers;
    char **siteFs;

    ImageGwServer **svrPtr;
    char **siteFsPtr;
    size_t siteFs_capacity;
    size_t servers_capacity;
} UdiRootConfig;

int parse_UdiRootConfig(UdiRootConfig *, int validateFlags);
void free_UdiRootConfig(UdiRootConfig *);
void fprint_UdiRootConfig(FILE *, UdiRootConfig *);
int validate_UdiRootConfig(UdiRootConfig *, int validateFlags);

#endif