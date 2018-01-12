#include <exec/types.h>
#include <exec/memory.h>

#include <proto/exec.h>
#include <proto/dos.h>
#include <proto/intuition.h>
#include <proto/expansion.h>

#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>

struct Library   *ExpansionBase = NULL;

void printCardROM(CONST APTR boardBase, struct ConfigDev *configDev)
{
  printf("Card ROM read @ %08x\n", boardBase);
  for (int i=0;i<16;i++)
    {
      unsigned char* boardRom = (unsigned char *)&(configDev->cd_Rom);
      printf("%02x ", boardRom[i]);
    }
  printf("\n");
}

bool checkCardOK(struct ConfigDev *configDev)
{
  bool result = false;

  if (configDev != NULL)
  {
    result = (configDev->cd_Rom.er_Type != 0) && (configDev->cd_Rom.er_Reserved03 == 0);
  }
  
  return result;
}

int main (int argc, char ** argv)
{
    UWORD m,i;
    UBYTE p,f,t;
    struct ConfigDev *configDev;

    printf("Zorro Hardware Debug Tool\n");
    printf("(C) 2017 S.J Leary\n");
    
    if((ExpansionBase=OpenLibrary("expansion.library",0L))==NULL)
    {
        printf("FATAL: Unable to open expansion.library\n");
        exit(RETURN_FAIL);
    }

    // Now we can use expansion.library
    while (1)
    {
        APTR boardBase = E_EXPANSIONBASE;
        configDev = NULL;
        configDev = AllocConfigDev();

        if (configDev == NULL)
        {
            printf("FATAL: unable to allocate the config dev structure\n");
            exit(RETURN_FAIL);
        }

        // read the expansion ROM
        ReadExpansionRom(boardBase, configDev );
	printCardROM(boardBase, configDev);
	
        if (!checkCardOK(configDev))
        {
	    boardBase = EZ3_EXPANSIONBASE;
	    // read the ZIII expansion ROM. 
            ReadExpansionRom(boardBase, configDev);
	    printCardROM(boardBase, configDev);
		
	    if (!checkCardOK(configDev))
	    {
	      printf("No more boards found to configure.\n");
	      break;
	    }
	    else
	    {
	      printf("ZIII Card Found\n");
	    }
        }
        else
        {
            printf("ZII Card Found\n");
        }

        printf("Now attempting to configure\n");

        configDev->cd_BoardAddr = (void *) boardBase;
        ConfigBoard(boardBase, configDev );
	
	/* These values were read directly from the board at expansion time */
        printf("Board ID (ExpansionRom) information:\n");
	
	t = configDev->cd_Rom.er_Type;
        m = configDev->cd_Rom.er_Manufacturer;
        p = configDev->cd_Rom.er_Product;
        f = configDev->cd_Rom.er_Flags;
        i = configDev->cd_Rom.er_InitDiagVec;

        printf("er_Manufacturer         =%d=$%04x=(~$%4x)\n",m,m,(UWORD)~m);
        printf("er_Product              =%d=$%02x=(~$%2x)\n",p,p,(UBYTE)~p);
        printf("er_Type                 =$%02x",configDev->cd_Rom.er_Type);

        if(configDev->cd_Rom.er_Type & ERTF_MEMLIST)
        {
            printf("  (Adds memory to free list)\n");
        }
        else
        {
            printf("\n");
        }

        printf("er_Flags                =$%02x=(~$%2x)\n",f,(UBYTE)~f);
        printf("er_InitDiagVec          =$%04x=(~$%4x)\n",i,(UWORD)~i);

        /* These values are generated when the AUTOCONFIG(tm) software
         * relocates the board
         */

        printf("Configuration (ConfigDev) information:\n");
        printf("cd_BoardAddr            =$%lx\n",configDev->cd_BoardAddr);
        printf("cd_BoardSize            =$%lx (%ldK)\n",
               configDev->cd_BoardSize,((ULONG)configDev->cd_BoardSize)/1024);

        printf("cd_Flags                =$%x",configDev->cd_Flags);

        if(configDev->cd_Flags & CDF_CONFIGME)
        {
            printf("\n");
        }
        else
        {
            printf("  (driver clears CONFIGME bit)\n");
        }
    }

    CloseLibrary(ExpansionBase);
}
