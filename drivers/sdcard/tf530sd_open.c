#include <exec/resident.h>
#include <exec/errors.h>
#include <exec/memory.h>
#include <exec/lists.h>
#include <exec/alerts.h>
#include <exec/tasks.h>
#include <exec/io.h>

#include <devices/scsidisk.h>

#include <proto/exec.h>

#include <stdio.h>


int main(int argc, char** argv) {
  int error;
struct MsgPort *SCSIMP;      /* Message port pointer */
struct IOStdReq *SCSIIO;     /* IORequest pointer */

    /* Create message port */
if (!(SCSIMP = CreatePort(NULL,NULL)))
  { printf("Can't create message port\n");};

    /* Create IORequest */
if (!(SCSIIO = CreateExtIO(SCSIMP,sizeof(struct IOStdReq))))
  {printf("Can't create IORequest\n");};

    /* Open the SCSI device */
if (error = OpenDevice("tf530sd.device",6L,SCSIIO,0L))
  {printf("Can't open scsi.device\n");}


    return 0;
}
