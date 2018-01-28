#include <exec/resident.h>
#include <exec/errors.h>
#include <exec/memory.h>
#include <exec/lists.h>
#include <exec/alerts.h>
#include <exec/tasks.h>
#include <exec/io.h>

#include <libraries/expansion.h>

#include <devices/trackdisk.h>
#include <devices/timer.h>
#include <devices/scsidisk.h>

#include <proto/exec.h>
#include <proto/disk.h>
#include <proto/expansion.h>

#include "tf530sd_cmd.h"

int main(int argc, char** argv) {
    unsigned int i=0;
    unsigned int block=0;
    struct SDUnit *unit = NULL;
    struct Library* ExpansionBase;
    struct ExecBase* SysBase = *(struct ExecBase **)4L;
    struct ConfigDev* cd = NULL;
    struct TF530SDRegs* registers = NULL;
    uint8* data = NULL;
    int res = 0;

    printf("TF530 SD card test v2\n");

    if ((ExpansionBase = (struct Library*)OpenLibrary("expansion.library",0L))==NULL) {
        printf("failed to open expansion.library!\n");
        return 1;
    }

    if (cd = (struct ConfigDev*)FindConfigDev(cd,0x13D8,0x81)) {
        printf("TF53x SPI Port Found.\n");
        registers = (struct TF530SDRegs*)(((uint8*)cd->cd_BoardAddr));
    } else {
        printf("No hardware Found.\n");
        return 1;
    }

    unit = (struct SDUnit *) malloc(sizeof(struct SDUnit));
    unit->sdu_Registers = registers;

    printf("Control register: %d\n",registers->ctrl);
    registers->ctrl = 0x2;
    printf("Control register: %d\n",registers->ctrl);

    printf("Resetting...\n");

    if (sd_reset(unit) == 0)
    {
        printf("done\n");
    }
    else
    {
    printf("failed\n");
        return 1;
    }
    
    data=(uint8*)malloc(100*512);
    memset(data,0xfe,100*512);

    printf("1 blocks write test...\n");
    res=sdcmd_write_blocks(unit,data,1000000,1); // approx. at 488 MB
    printf("done. res=%d\n",res);
    sd_reset(unit);

    printf("10 blocks write test...\n");
    res=sdcmd_write_blocks(unit,data,1000000,10); // approx. at 488 MB
    printf("done. res=%d\n",res);
    sd_reset(unit);

    printf("100 blocks write test...\n");
    res=sdcmd_write_blocks(unit,data,1000000,100); // approx. at 488 MB
    printf("done. res=%d\n",res);
    sd_reset(unit);

    printf("1000 blocks write test...\n");
    res=sdcmd_write_blocks(unit,data,1000000,1000); // approx. at 488 MB
    printf("done. res=%d\n",res);
    sd_reset(unit);

    printf("10000 blocks write test...\n");
    res=sdcmd_write_blocks(unit,data,1000000,10000); // approx. at 488 MB
    printf("done. res=%d\n",res);
    free(unit);
    free(data);
}
