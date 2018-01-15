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

#include <dos/filehandler.h>

#include <proto/exec.h>
#include <proto/disk.h>
#include <proto/expansion.h>

#include "tf530sd_cmd.h"

/*
 *  SD card commands
 */
/* Basic command class */
#define CMD0        0           /* GO_IDLE_STATE: response type R1 */
#define CMD1        1           /* SEND_OP_COND: response type R1 */
#define CMD8        8           /* SEND_IF_COND: response type R7 */
#define CMD9        9           /* SEND_CSD: response type R1 */
#define CMD10       10          /* SEND_CID: response type R1 */
#define CMD12       12          /* STOP_TRANSMISSION: response type R1B */
#define CMD13       13          /* SEND_STATUS: response type R2 */
#define CMD58       58          /* READ_OCR: response type R3 */
/* Block read command class */
#define CMD16       16          /* SET_BLOCKLEN: response type R1 */
#define CMD17       17          /* READ_SINGLE_BLOCK: response type R1 */
#define CMD18       18          /* READ_MULTIPLE_BLOCK: response type R1 */
/* Block write command class */
#define CMD24       24          /* WRITE_BLOCK: response type R1 */
#define CMD25       25          /* WRITE_MULTIPLE_BLOCK: response type R1 */
/* Application-specific command class */
#define CMD55       55          /* APP_CMD: response type R1 */
#define ACMD13      13          /* SD_STATUS: response type R2 (in SPI mode only!) */
#define ACMD41      41          /* SD_SEND_OP_COND: response type R1 */
#define ACMD51      51          /* SEND_SCR: response type R1 */

/*
 *  SD card response types
 */
#define R1          1
#define R1B         2
#define R2          3
#define R3          4
#define R7          5

#define LOBYTE(x) ((uint8)(uint16)(x))

/*
 *  SD error code bits
 */
#define SD_ERR_IDLE_STATE       0x01
#define SD_ERR_ILLEGAL_CMD      0x04

#define CARDTYPE_UNKNOWN    0
#define CARDTYPE_MMC        1
#define CARDTYPE_SD         2
#define BLOCK_ADDRESSING    0x02
#define MULTIBLOCK_IO       0x01
#define SECTOR_SIZE     512 /* standard for floppy, hard disk */


/*
 *  SD timeouts
 */
/* a useful macro */
/* these are byte-count timeout values */
#define SD_CMD_TIMEOUT          8       /* between sending crc & receiving response */
#define SD_CSD_TIMEOUT          8       /* between sending SEND_CSD cmd & receiving data */
/* these are millisecond timeout values (see SD specifications v4.10) */
#define SD_POWERUP_DELAY_MSEC   1       /* minimum power-up time */
#define SD_INIT_TIMEOUT_MSEC    1000    /* waiting for card to become ready */
#define SD_READ_TIMEOUT_MSEC    100     /* waiting for start bit of data block */
#define SD_WRITE_TIMEOUT_MSEC   500     /* waiting for end of busy */
/* these are derived timeout values in TOS ticks */
//#define SD_POWERUP_DELAY_TICKS  msec_to_ticks(SD_POWERUP_DELAY_MSEC)
//#define SD_INIT_TIMEOUT_TICKS   msec_to_ticks(SD_INIT_TIMEOUT_MSEC)
#define SD_READ_TIMEOUT_TICKS   25000000
#define SD_WRITE_TIMEOUT_TICKS  25000000

/*
 *  SD data tokens
 */
#define DATAERROR_TOKEN_MASK    0xf0    /* for reads: error token is 0000EEEE */
#define DATARESPONSE_TOKEN_MASK 0x1f    /* for writes: data response token is xxx0sss1 */
#define START_MULTI_WRITE_TOKEN 0xfc
#define STOP_TRANSMISSION_TOKEN 0xfd
#define START_BLOCK_TOKEN       0xfe

/*
 *  miscellaneous
 */
#define SDV2_CSIZE_MULTIPLIER   1024    /* converts C_SIZE to sectors */
#define DELAY_1_MSEC            delay_loop(loopcount_1_msec)

#define CRC_RETRIES 3

#define LOOP_TIMEOUT 200000
//static uint32 LOOP_TIMEOUT=20000;

//#define bug(x,args...) kprintf(x ,##args);
//#define debug(x,args...) bug("%s:%ld " x "\n", __func__, (unsigned long)__LINE__ ,##args)

const uint16 crc_table[256] = {
    0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7,
    0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef,
    0x1231, 0x0210, 0x3273, 0x2252, 0x52b5, 0x4294, 0x72f7, 0x62d6,
    0x9339, 0x8318, 0xb37b, 0xa35a, 0xd3bd, 0xc39c, 0xf3ff, 0xe3de,
    0x2462, 0x3443, 0x0420, 0x1401, 0x64e6, 0x74c7, 0x44a4, 0x5485,
    0xa56a, 0xb54b, 0x8528, 0x9509, 0xe5ee, 0xf5cf, 0xc5ac, 0xd58d,
    0x3653, 0x2672, 0x1611, 0x0630, 0x76d7, 0x66f6, 0x5695, 0x46b4,
    0xb75b, 0xa77a, 0x9719, 0x8738, 0xf7df, 0xe7fe, 0xd79d, 0xc7bc,
    0x48c4, 0x58e5, 0x6886, 0x78a7, 0x0840, 0x1861, 0x2802, 0x3823,
    0xc9cc, 0xd9ed, 0xe98e, 0xf9af, 0x8948, 0x9969, 0xa90a, 0xb92b,
    0x5af5, 0x4ad4, 0x7ab7, 0x6a96, 0x1a71, 0x0a50, 0x3a33, 0x2a12,
    0xdbfd, 0xcbdc, 0xfbbf, 0xeb9e, 0x9b79, 0x8b58, 0xbb3b, 0xab1a,
    0x6ca6, 0x7c87, 0x4ce4, 0x5cc5, 0x2c22, 0x3c03, 0x0c60, 0x1c41,
    0xedae, 0xfd8f, 0xcdec, 0xddcd, 0xad2a, 0xbd0b, 0x8d68, 0x9d49,
    0x7e97, 0x6eb6, 0x5ed5, 0x4ef4, 0x3e13, 0x2e32, 0x1e51, 0x0e70,
    0xff9f, 0xefbe, 0xdfdd, 0xcffc, 0xbf1b, 0xaf3a, 0x9f59, 0x8f78,
    0x9188, 0x81a9, 0xb1ca, 0xa1eb, 0xd10c, 0xc12d, 0xf14e, 0xe16f,
    0x1080, 0x00a1, 0x30c2, 0x20e3, 0x5004, 0x4025, 0x7046, 0x6067,
    0x83b9, 0x9398, 0xa3fb, 0xb3da, 0xc33d, 0xd31c, 0xe37f, 0xf35e,
    0x02b1, 0x1290, 0x22f3, 0x32d2, 0x4235, 0x5214, 0x6277, 0x7256,
    0xb5ea, 0xa5cb, 0x95a8, 0x8589, 0xf56e, 0xe54f, 0xd52c, 0xc50d,
    0x34e2, 0x24c3, 0x14a0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,
    0xa7db, 0xb7fa, 0x8799, 0x97b8, 0xe75f, 0xf77e, 0xc71d, 0xd73c,
    0x26d3, 0x36f2, 0x0691, 0x16b0, 0x6657, 0x7676, 0x4615, 0x5634,
    0xd94c, 0xc96d, 0xf90e, 0xe92f, 0x99c8, 0x89e9, 0xb98a, 0xa9ab,
    0x5844, 0x4865, 0x7806, 0x6827, 0x18c0, 0x08e1, 0x3882, 0x28a3,
    0xcb7d, 0xdb5c, 0xeb3f, 0xfb1e, 0x8bf9, 0x9bd8, 0xabbb, 0xbb9a,
    0x4a75, 0x5a54, 0x6a37, 0x7a16, 0x0af1, 0x1ad0, 0x2ab3, 0x3a92,
    0xfd2e, 0xed0f, 0xdd6c, 0xcd4d, 0xbdaa, 0xad8b, 0x9de8, 0x8dc9,
    0x7c26, 0x6c07, 0x5c64, 0x4c45, 0x3ca2, 0x2c83, 0x1ce0, 0x0cc1,
    0xef1f, 0xff3e, 0xcf5d, 0xdf7c, 0xaf9b, 0xbfba, 0x8fd9, 0x9ff8,
    0x6e17, 0x7e36, 0x4e55, 0x5e74, 0x2e93, 0x3eb2, 0x0ed1, 0x1ef0
};

static int sd_command(struct TF530SDRegs* port, uint8 cmd, uint32 argument, uint8 crc, uint8 resp_type, uint8 *resp);

static inline uint16 crc(uint16 crc, uint8 data)
{
    return (crc << 8) ^ crc_table[((crc >> 8) ^ data) & 0xff];
}


#define TF530_CTRL_CS0 1
#define TF530_CTRL_CS1 2
#define TF530_CTRL_BUSY 4

void inline spi_send_byte(struct TF530SDRegs* port, uint8 value)
{
    uint8 busy = 0;

    while (busy  == 0)
    {
        busy = port->ctrl & TF530_CTRL_BUSY;
    }

    port->data = value;
}

uint8 inline spi_recv_byte(struct TF530SDRegs* port)
{
    uint8 busy = 0;

    while (busy  == 0)
    {
        busy = port->ctrl & TF530_CTRL_BUSY;
    }

    return port->data;
}

uint8 spi_cs_unassert(struct TF530SDRegs* port)
{
    uint8 current = port->ctrl;
    port->ctrl = current | TF530_CTRL_CS0 | TF530_CTRL_CS1;
    // return the old state
    return current;
}

void spi_cs_assert(struct TF530SDRegs* port, uint8 newstate)
{
    port->ctrl = newstate;
}

/*
 *  initialisation function:
 *      loops, issuing command & waiting for card to become "un-idle"
 *
 *  assumes that input cmd is 1 or 41 and, if it's 41,
 *  it's ACMD41 and so must be preceded by CMD55
 *
 *  returns 0   ok
 *          -1  timeout
 */
static int sd_wait_for_not_idle(struct TF530SDRegs* port, uint8 cmd, uint32 arg)
{
    uint8 response[5];
    uint32 end = 0;

    while(end < 10000) {
        if (cmd == ACMD41)
            if (sd_command(port, CMD55,0L,0,R1,response) < 0)
                break;
        if (sd_command(port, cmd,arg,0,R1,response) < 0)
            break;
        if ((response[0] & SD_ERR_IDLE_STATE) == 0)
            return 0;
        end++;
    }

    return -1;
}


/*
 *  wait for not busy indication
 *
 *  note: timeout value is in ticks
 *
 *  returns -1  timeout
 *          0   ok
 */
static int sd_wait_for_not_busy(struct TF530SDRegs* port, int timeout)
{
    uint32 end = 0L;
    uint8 c;

    while(end < timeout) {
        c = spi_recv_byte(port);
        if (c != 0x00)
            return 0;
        end++;
    }

    return -1;
}

/*
 *  wait for ready indication
 *
 *  note: timeout value is in ticks
 *
 *  returns -1  timeout
 *          0   ok
 */
static int sd_wait_for_ready(struct TF530SDRegs* port, int timeout)
{
    uint32 end = 0L;
    uint8 c;

    while(end < timeout) {
        c = spi_recv_byte(port);
        if (c == 0xff)
            return 0;
        end++;
    }

    return -1;
}

/*
 *  receive data block
 *
 *  notes:
 *  1. if 'buf' is NULL, we throw away the received data
 *  2. if 'special' is non-zero, we use the special SD_CSD_TIMEOUT
 *     instead of the standard read timeout
 *
 *  returns -1 timeout or unexpected start token
 *          0   ok
 */
static int sd_receive_data(struct TF530SDRegs* port, uint8 *buf, uint16 len,uint16 special)
{
    int i;
    uint8 token;

    /* wait for the token */
    if (special) {
        for (i = 0; i < SD_CSD_TIMEOUT; i++) {
            token = spi_recv_byte(port);
            if (token != 0xff)
                break;
        }
    } else {
        uint32 end = 0;
        while(end < 200000) {
            token = spi_recv_byte(port);
            if (token != 0xff)
                break;
            end++;
        }
    }
    if (token == 0xff)
        return -1;

    /* check for valid token */
    if (token != START_BLOCK_TOKEN) {
        printf("sd_receive_data() bad startblock token 0x%02x\n",token);
        return -1;
    }

    /*
     *  transfer data
     */
    if (buf) {
        for (i = 0; i < len; i++)
            *buf++ = spi_recv_byte(port);
    } else {
        for (i = 0; i < len; i++)
            spi_recv_byte(port);
    }

    spi_recv_byte(port);        /* discard crc */
    spi_recv_byte(port);

    return 0;
}


/*
 *  test if multiple block i/o works
 *  returns 0 iff true
 */
static int sd_mbtest(struct TF530SDRegs* port)
{
    uint8 response[5];
    /*
     *  see if READ_MULTIPLE_BLOCK/STOP_TRANSMISSION work
     *  if they do, we assume the write stuff works too
     */
    if (sd_command(port, CMD18,0L,0,R1,response))
        return -1;

    sd_receive_data(port, NULL,SECTOR_SIZE,0);
    if (sd_command(port, CMD12,0L,0,R1B,response))
        return -1;

    return 0;
}


/*
 *  determine card type & version
 */
static void sd_cardtype(struct SDUnit *unit)
{
    int rc;
    uint8 response[5];
    UBYTE csd[16];

    struct TF530SDRegs* port = (struct TF530SDRegs*)unit->sdu_Registers;
    unit->sdu_CardType = CARDTYPE_UNKNOWN;          /* defaults */
    unit->sdu_CardVersion = 0;

    /*
     *  check first for SDv2
     */
    if ((sd_command(port, CMD8,0x000001aaL,0x87,R7,response) >= 0)
            && ((response[0]&SD_ERR_ILLEGAL_CMD) == 0)) {
        printf("CMD8 R7 = %02x:%02x:%02x:%02x:%02x\n", response[0], response[1], response[2], response[3], response[4]);
        if ((response[3]&0x0f) != 0x01)     /* voltage not accepted */
            return;
        if (response[4] != 0xaa)            /* check pattern mismatch */
            return;
        if (sd_wait_for_not_idle(port, ACMD41,0x40000000L) != 0)
            return;
        unit->sdu_CardType = CARDTYPE_SD;
        unit->sdu_CardVersion = 2;
        return;
    }

    /*
     *  check for SDv1
     */
    rc = sd_wait_for_not_idle(port, ACMD41,0L);
    if (rc == 0) {
        unit->sdu_CardType = CARDTYPE_SD;
        unit->sdu_CardVersion = 1;
        return;
    }

    /*
     *  check for MMC
     */
    rc = sd_wait_for_not_idle(port, CMD1,0L);
    if (rc) {
        unit->sdu_CardType = CARDTYPE_UNKNOWN;
        return;
    }
    unit->sdu_CardType = CARDTYPE_MMC;

    /*
     *  determine MMC version from CSD
     */
    if (sd_command(port, CMD9,0L,0,R1,response) == 0)
        if (sd_receive_data(port, csd,16,1) == 0)
            unit->sdu_CardVersion = (csd[0] >> 2) & 0x0f;
}

/*
 *  determine card features
 */
static void sd_features(struct SDUnit* unit)
{
    uint8 response[5];
    struct TF530SDRegs* port = (struct TF530SDRegs*)unit->sdu_Registers;
    unit->sdu_CardFeatures = 0;

    /*
     *  check SDv2 for block addressing
     */
    if ((unit->sdu_CardType == CARDTYPE_SD) && (unit->sdu_CardVersion == 2)) {
        if (sd_command(port, CMD58,0L,0,R3,response) != 0) {  /* shouldn't happen */
            unit->sdu_CardType = CARDTYPE_UNKNOWN;
            unit->sdu_CardVersion = 0;
            return;
        }
        if (response[1] & 0x40)
            unit->sdu_CardFeatures |= BLOCK_ADDRESSING;
    }

    /*
     *  all SD cards support multiple block I/O
     */
    if (unit->sdu_CardType == CARDTYPE_SD) {
        unit->sdu_CardFeatures |= MULTIBLOCK_IO;
        return;
    }

    /*
     *  check MMC for multiple block I/O support
     *  v3 cards always have it ... but so do some v2 & v1 cards
     */
    if (unit->sdu_CardType == CARDTYPE_MMC) {
        if (unit->sdu_CardVersion == 3)
            unit->sdu_CardFeatures |= MULTIBLOCK_IO;
        else if (sd_mbtest(port) == 0)
            unit->sdu_CardFeatures |= MULTIBLOCK_IO;
    }
}


/*
 *  send a command to the SD card in SPI mode
 *
 *  returns -1  timeout or bad response type
 *          0   OK
 *          >0  error status from response[0]
 */
static int sd_command(struct TF530SDRegs* port, uint8 cmd, uint32 argument, uint8 crc, uint8 resp_type, uint8 *resp)
{
    int i, resp_length;

    /*
     *  set up response length
     */
    switch(resp_type) {
    case R1:
    case R1B:
        resp_length = 1;
        break;
    case R2:
        resp_length = 2;
        break;
    case R3:
    case R7:
        resp_length = 5;
        break;
    default:
        return -1;
    }

    /*
     *  the following test serves two functions:
     *  1. it ensures that at least one byte is clocked out before sending
     *     the command.  some cards seem to require this, at least during
     *     the initialisation sequence.
     *  2. it cleans up any residual data that the card may be sending as
     *     a result of a previous command that experienced problems.
     */
    if (sd_wait_for_ready(port, 10000) < 0)
        return -1;

    /* Send the command byte, argument, crc */
    spi_send_byte(port, (cmd & 0x3f) | 0x40);

    spi_send_byte(port, (argument>>24)&0xff);
    spi_send_byte(port, (argument>>16)&0xff);
    spi_send_byte(port, (argument>>8)&0xff);
    spi_send_byte(port, argument&0xff);

    /* CRC is ignored by default in SPI mode ... but we always need a stop bit! */
    spi_send_byte(port, crc|0x01);

    if (cmd == CMD12)                   /* stop transmission: */
        spi_recv_byte(port);            /* always discard first byte */

    /* now we look for the response, which starts with a byte with the 0x80 bit clear */
    for (i = 0; i < SD_CMD_TIMEOUT; i++) {
        resp[0] = spi_recv_byte(port);
        if ((resp[0]&0x80) == 0)
            break;
    }
    if (i >= SD_CMD_TIMEOUT)            /* timed out */
        return -1;

    /*
     *  retrieve remainder of response iff command is legal
     *  (if it's illegal, it's effectively an R1 response type)
     */
    if ((resp[0] & SD_ERR_ILLEGAL_CMD) == 0) {
        for (i = 1; i < resp_length; i++)
            resp[i] = spi_recv_byte(port);
    }

    /*
     *  for R1B responses, we need to wait for the end of the busy state.
     *  R1B is only set by write-type commands (CMD12, CMD28, CMD29, CMD38)
     *  so we use the write timeout here.
     */
    if (resp_type == R1B)
        if (sd_wait_for_not_busy(port, 10000) < 0)
            return -1;

    return resp[0];
}


int sd_reset(void* units) {
    uint32 i=0;
    int rc;
    uint8 response[5];
    struct SDUnit *unit = (struct SDUnit*)units;
    struct TF530SDRegs* port = (struct TF530SDRegs*)unit->sdu_Registers;

    /* send at least 74 dummy clocks with CS unasserted (high) */

    uint8 oldstate = spi_cs_unassert(port);

    for (i = 0; i < 10; i++)
    {
        spi_send_byte(port, 0xff);
    }

    spi_cs_assert(port, oldstate);

    /*
     *  if CMD0 doesn't cause a switch to idle state, there's
     *  probably no card inserted, so exit with error
     */
    rc = sd_command(port, CMD0,0L,0x95,R1,response);
    if ((rc < 0) || !(rc&SD_ERR_IDLE_STATE)) {
        printf("CMD0 failed, rc=%d, response=0x%02x\n",rc,response[0]);
        unit->sdu_CardType = CARDTYPE_UNKNOWN;
        //spi_cs_unassert(port);
        return 1;
    }

    /* now switch into SPI Mode.. this is mandatory */
    rc = sd_command(port, CMD8,0x1AAL,0x87,R1,response);
    if ((rc < 0) || !(rc&SD_ERR_IDLE_STATE)) {
        printf("CMD8 failed, rc=%d, response=0x%02x\n",rc,response[0]);
        unit->sdu_CardType = CARDTYPE_UNKNOWN;
        //spi_cs_unassert(port);
        return 2;
    }

    /*
     *  determine card type, version, features
     */
    sd_cardtype(unit);
    sd_features(unit);

    /*
     *  force block length to SECTOR_SIZE if byte addressing
     */
    if (unit->sdu_CardType != CARDTYPE_UNKNOWN)
        if (!(unit->sdu_CardFeatures&BLOCK_ADDRESSING))
            if (sd_command(port, CMD16,SECTOR_SIZE,0,R1,response) != 0)
                unit->sdu_CardType = CARDTYPE_UNKNOWN;

    printf("Card info: type %d, version %d, features 0x%02x\n",
           unit->sdu_CardType,unit->sdu_CardVersion,unit->sdu_CardFeatures);

    return 0;
}

/*
 *  get the data response.  although it *should* be the byte
 *  immediately after the data transfer, some cards miss the
 *  time frame by one or more bits, so we check bit-by-bit.
 *
 *  idea stolen from the linux driver mmc_spi.c
 */
static uint8 sd_get_dataresponse(struct TF530SDRegs* port)
{
uint32 pattern;

        pattern = (uint32)spi_recv_byte(port) << 24;    /* accumulate 4 bytes */
        pattern |= (uint32)spi_recv_byte(port) << 16;
        pattern |= (uint32)spi_recv_byte(port) << 8;
        pattern |= (uint32)spi_recv_byte(port);

        /* the first 3 bits are undefined */
        pattern |= 0xe0000000L;             /* first 3 bits are undefined */

        /* left-adjust to leading 0 bit */
        while(pattern & 0x80000000L)
            pattern <<= 1;

        /* right-adjust to put code into bits 4-0 */
        pattern >>= 27;

        return LOBYTE(pattern);
}

/*
 *  send data block
 *
 *  returns -1  timeout or bad response token
 *          0   ok
 */
static int sd_send_data(struct TF530SDRegs* port, uint8 *buf,UWORD len,uint8 token)
{
int i;
uint8 rtoken;

    spi_send_byte(port, token);
    if (token == STOP_TRANSMISSION_TOKEN) {
        spi_recv_byte(port);    /* skip a byte before testing for busy */
    } else {
        /* send the data */
        for (i = 0; i < len; i++)
	  spi_send_byte(port, *buf++);
        spi_send_byte(port, 0xff);        /* send dummy crc */
        spi_send_byte(port, 0xff);

        /* check the data response token */
        rtoken = sd_get_dataresponse(port);
        if ((rtoken & DATARESPONSE_TOKEN_MASK) != 0x05) {
	  //KDEBUG(("sd_send_data() response token 0x%02x\n",rtoken));
            return -1;
        }
    }

    return sd_wait_for_not_busy(port, 10000);
}

/*
 *  write one or more blocks
 *
 *  note: we don't use the pre-erase function, since
 *  it doesn't seem to improve performance
 */
static int sd_write(struct SDUnit *unit, uint16 drv,uint32 sector, uint16 count,uint8 *buf)
{
    int i, rc, rc2;
    int posn, incr;
    uint8 response[5];

    struct TF530SDRegs* port = (struct TF530SDRegs*)unit->sdu_Registers;

    //spi_cs_assert(port, 0x2);

    /*
     *  handle byte/block addressing
     */
    if (unit->sdu_CardFeatures & BLOCK_ADDRESSING) {
        posn = sector;
        incr = 1;
    } else {
        posn = sector * SECTOR_SIZE;
        incr = SECTOR_SIZE;
    }

    rc = 0L;

    /*
     *  can we use multi sector writes?
     */
    if ((count > 1) && (unit->sdu_CardFeatures&MULTIBLOCK_IO)) {
        rc = sd_command(port,CMD25,posn,0,R1,response);
        if (rc == 0L) {
            for (i = 0; i < count; i++, buf += SECTOR_SIZE) {
                rc = sd_send_data(port, buf,SECTOR_SIZE,START_MULTI_WRITE_TOKEN);
                if (rc)
                    break;
            }
            rc2 = sd_send_data(port, NULL,0,STOP_TRANSMISSION_TOKEN);
            if (rc == 0)
                rc = rc2;
        }
    } else {            /* use single sector write */
        for (i = 0; i < count; i++, posn += incr, buf += SECTOR_SIZE) {
            rc = sd_command(port, CMD24,posn,0,R1,response);
            if (rc == 0L)
                rc = sd_send_data(port, buf,SECTOR_SIZE,START_BLOCK_TOKEN);
            if (rc)
                break;
        }
    }

    //spi_cs_unassert(port);

    return rc;
}

/*
 *  read one or more blocks
 */
static int sd_read(struct SDUnit *unit, uint16 drv,uint32 sector, uint16 count,uint8 *buf)
{
int i, rc, rc2;
int posn, incr;
    uint8 response[5];

    struct TF530SDRegs* port = (struct TF530SDRegs*)unit->sdu_Registers;

    //spi_cs_assert(port, 0xFE);

    /*
     *  handle byte/block addressing
     */
    if (unit->sdu_CardFeatures&BLOCK_ADDRESSING) {
        posn = sector;
        incr = 1;
    } else {
        posn = sector * SECTOR_SIZE;
        incr = SECTOR_SIZE;
    }

    rc = 0L;

    /*
     *  can we use multi sector reads?
     */
    if ((count > 1) && (unit->sdu_CardFeatures&MULTIBLOCK_IO)) {
      rc = sd_command(port, CMD18,posn,0,R1,response);
        if (rc == 0L) {
            for (i = 0; i < count; i++, buf += SECTOR_SIZE) {
	      rc = sd_receive_data(port, buf,SECTOR_SIZE,0);
                if (rc)
                    break;
            }
            rc2 = sd_command(port, CMD12,0L,0,R1B,response);
            if (rc == 0)
                rc = rc2;
        }
    } else {            /* use single sector */
        for (i = 0; i < count; i++, posn += incr, buf += SECTOR_SIZE) {
	  rc = sd_command(port, CMD17,posn,0,R1,response);
            if (rc == 0L)
	      rc = sd_receive_data(port, buf,SECTOR_SIZE,0);
            if (rc)
                break;
        }
    }

    //spi_cs_unassert(port);

    return rc;
}

uint16 sdcmd_read_blocks(void* units, uint8* data, uint32 block, uint32 len) {
    uint16 block_crc=0;
    uint8 problems=0;
    uint8 t = 0;
    struct SDUnit *unit = (struct SDUnit*)units;
    volatile struct TF530SDRegs* port = (struct TF530SDRegs*)unit->sdu_Registers;
    sd_read(unit, 0, block, len, data);
    
    if (problems) {
        return SDERRF_TIMEOUT;
    }
    /*    if (block_crc!=block_crc_actual) {
      return SDERRF_CRC;
      }*/

    return 0;
}

uint16 sdcmd_write_blocks(void* units, uint8* data, uint32 block, uint32 len) {
    uint8 problems=0;
    struct SDUnit *unit = (struct SDUnit*)units;
    volatile struct TF530SDRegs* port = (struct TF530SDRegs*)unit->sdu_Registers;
    uint8 res = sd_write(unit, 0, block, len, data);

    if (problems) {
        return SDERRF_TIMEOUT;
    }

    return res; 
}

uint16 sdcmd_present() {
    return 1;
}

uint16 sdcmd_detect() {
    return 0;
}
