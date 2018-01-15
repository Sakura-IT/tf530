#ifndef TF530SD_H
#define TF530SD_H

#define uint32 unsigned long
#define uint8 unsigned char
#define uint16 unsigned short

#define SD_HEADS         1
#define SD_CYLS          1024 /* 1024 MB */
#define SD_TRACK_SECTORS 2048 /* 1 MB */
#define SD_CYL_SECTORS   2048 /* TRACK_SECTORS * HEADS */
#define SD_SECTOR_BYTES  512
#define SD_SECTOR_SHIFT  9
#define SD_RETRY         10

#define SDERRF_TIMEOUT  (1 << 7)
#define SDERRF_PARAM    (1 << 6)
#define SDERRF_ADDRESS  (1 << 5)
#define SDERRF_ERASESEQ (1 << 4)
#define SDERRF_CRC      (1 << 3)
#define SDERRF_ILLEGAL  (1 << 2)
#define SDERRF_ERASERES (1 << 1)
#define SDERRF_IDLE     (1 << 0)

#define SD_UNITS    1       /* Only one chip select for now */

#define SDU_STACK_SIZE  (4096 / sizeof(ULONG))

#define CMD_NAME(x) if (cmd == x) return #x
#define TD_READ64     24
#define TD_WRITE64    25
#define TD_SEEK64     26
#define TD_FORMAT64   27

/*const char *cmd_name(int cmd)
{
  CMD_NAME(CMD_READ);
  CMD_NAME(CMD_WRITE);
  CMD_NAME(CMD_UPDATE);
  CMD_NAME(CMD_CLEAR);
  CMD_NAME(TD_ADDCHANGEINT);
  CMD_NAME(TD_CHANGENUM);
  CMD_NAME(TD_CHANGESTATE);
  CMD_NAME(TD_EJECT);
  CMD_NAME(TD_FORMAT);
  CMD_NAME(TD_GETDRIVETYPE);
  CMD_NAME(TD_GETGEOMETRY);
  CMD_NAME(TD_MOTOR);
  CMD_NAME(TD_PROTSTATUS);
  CMD_NAME(TD_READ64);
  CMD_NAME(TD_REMCHANGEINT);
  CMD_NAME(TD_WRITE64);
  CMD_NAME(HD_SCSICMD);

  return "Unknown";
  }*/

struct TF530SDRegs {
  volatile uint8 ctrl; // Control register
  volatile uint8 unused1; // Control register
  volatile uint8 unused2; // Control register
  volatile uint8 unused3 ; // Control register
  volatile uint8 data; // data
};

struct SDBase {
  struct Device* sd_Device;
  struct SDUnit {
    struct Unit sdu_Unit;

    /*struct Unit {
        struct  MsgPort unit_MsgPort;
        UBYTE   unit_flags;
                UNITF_ACTIVE = 1
                UNITF_INTASK = 2 
        UBYTE   unit_pad;
        UWORD   unit_OpenCnt;
    };*/
    
    BOOL        sdu_Enabled;

    void* sdu_Registers;

    uint8 sdu_CardType;
    uint8 sdu_CardVersion;
    uint8 sdu_CardFeatures;

    BOOL sdu_Present;               /* Is a device detected? */
    BOOL sdu_Valid;                 /* Is the device ready for IO? */
    BOOL sdu_ReadOnly;              /* Is the device read-only? */
    BOOL sdu_Motor;                 /* TD_MOTOR state */
    ULONG sdu_ChangeNum;
  } sd_Unit[SD_UNITS];
};

uint16 sdcmd_read_blocks(void* registers, uint8* data, uint32 block, uint32 len);
uint16 sdcmd_write_blocks(void* registers, uint8* data, uint32 block, uint32 len);
uint16 sdcmd_present();
uint16 sdcmd_detect();
void sd_set_testmem(uint8* m);
int sd_reset(void* regs);

#endif
