# Project Worklog & Technical Notes

## Goals

### Primary Objectives
Add escmfg for Kontronik ESC  

## Work Done

#### Make UI for Kontronik ESC
- escmfg / kontr + i18n en.json + ESC_PARAMETERS_KONTRONIK.LUA  
- **Status:** Completed / Experimental - SIM is working  

## ToDo

#### Read Actual Values from ESC 
- **Description:**  RF has to read the provided stream. The provided Fields (i.E. 8208 for BEC Voltage) have to be mapped to the coresponding ETHOS Suite fields ( For BEC Voltage {field = "bec_voltage", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = bec_voltage} )
- **Files / Modules Affected:**  
- **Status:** next step 2  

#### Write Actual Values to ESC 
- **Description:**  RF has to write changed settings
- **Files / Modules Affected:**  
- **Status:** step 3  

## Technical Notes
Serial Communication has to beginn with an Handshake

On the boot phase, the ESC sends 3 AT commands and wait for response from the module.
    +++\r
    response: \r\n
    AT\r
    response: \r\nOK\r\n
    ATSN?\r
    response: \r\nOK\r\n\r\nKONTRONIKBT\r\n
KONTRONIKBT tells us that we are ready to receive and send

The Kontronik ESCs (Kosmik, Kolibri and Jive pro) are utilizing a full duplex 8 bit 115200 1 stop bit no parity 3.3v UART communication via the JST-ZH1.5 5 pin connector

The String that is received after the handshake is like this:
§G1001 §E92:8192;1025:8194;87588:16388;800:8200;3000:8202;2300:8204;1000:8206;7600:8208;2000:8210;5:8212;1001:8214;1001:8216;2001:8218;1365:8220;0:8222;1365:12320;8000:8226;4000:8228;12000:8230;4:8232;4:8234;0:8236;30000:16432;300:8244;40:12346;100:8252;100:8254;0:12352;4096:12354;24000:16452;_4:8264_;100:8266;3500:8268;250:8270;90:8272;90:8274;12500:8276;0:8278;4294624904:16472;  ...all Parameters...

...§G1001 §V §L23=25.9 V;24=0 A;25=0 A;26=5.6 V;27=0.4 A;28=21 '22;29=19 '22; §M5=0 '6;7=0 A;8=0 °; §A2=26.0 V;3=0 A;4=0 mAh; §R1=0.5 s;10=7.6 V;11=0.2 A;12=20 '22;13=0 %;14=0 '6;15=0 %;16=19 '22;19=1001 us;20=11;--R=KOSMIK200+HV;--P=1;  ...all stati...

In the Line starting with §G1001 §E92:8192; the on the ESC stored Programming Parameters are provided.
- I.E. The BEC Voltage is stored in Field 8208 and it's provided like this 7400:8208, meaning 7400mV
- To chnge the BEC Value to 6000mV, we have to send §§6000:8208;6000:8208 
- Some Values are critical to change, the ESC has to be activate for special programming via $$23:24576;23:24576 and then the changed Value with $$5:12352;5:12352 and then deactivate for special programming via $$38:24576;38:24576

In the Line starting with §G1001 §V actual Live Data is provided. Important for ETHOS-Suite is this field "--R=KOSMIK200+HV" or "--R = KOLIBRI140+LV" wich contains the ESC model

feature for later implementation the LUA File esc_status.lua should display the important status values (i.E. Error-Codes)

## Known Issues / Limitations
Has to read and write RX and TX separate in this State because it is unknown if we can transfer via Half Duplex
ESC is Providing am Handshake we have to answer. This is only provided when powering up?
(On the boot phase, the ESC sends 3 AT commands and wait for response from the module.
    +++\r
    response: \r\n
    AT\r
    response: \r\nOK\r\n
    ATSN?\r
    response: \r\nOK\r\n\r\nKONTRONIKBT\r\n
)
if we answer to the handshake, we can receive the actual settings and status and can Program the ESC

## Open Questions

How to get an Handshake if ESC is allready powerd u and not sednding anything. Maxbee via programming button?
How to send and receive via MSP
How to build an developer environment to debug the received string
How to map string values from the ESC Stream to Fields

## Screenshots
<img width="783" height="398" alt="grafik" src="https://github.com/user-attachments/assets/11f46986-0e0d-481a-8581-ea0dd1b36a36" />
<img width="792" height="327" alt="grafik" src="https://github.com/user-attachments/assets/e8ed40c5-49be-4b62-b7fe-232d49ebe402" />
<img width="795" height="485" alt="grafik" src="https://github.com/user-attachments/assets/9ba4c140-30bc-471d-b633-78a114d1b132" />
<img width="799" height="466" alt="grafik" src="https://github.com/user-attachments/assets/ab741a4b-c65e-4225-a243-ff37f973213d" />
<img width="795" height="469" alt="grafik" src="https://github.com/user-attachments/assets/77378e19-4035-4771-ba15-e582ab9c49e1" />




