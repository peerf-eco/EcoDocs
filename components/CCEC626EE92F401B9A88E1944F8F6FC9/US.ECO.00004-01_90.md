![logo](img_US.ECO.00004-01_90/header-logo.png)  
  
  
  
  
****  
Title: Eco.Semaphore1 Software Component Specification  
    
USPD: US.ECO.00004-01 90  
Component Name: Eco.Semaphore1  
Short Description (max 300 char.): implements Semaphore  
Component Use Category: MULTIPURPOSE   
Component Type:  UTILITY  
CID: CCEC626EE92F401B9A88E1944F8F6FC9  
Marketplace URL: n/a  
Status: Draft  
Modified Date: October 19, 2025  
Version: 1.0  
  
Tags: n/a  
  
  
|**Authors**|**Company**|
| --- | --- |
|Vladimir Bashev|PEERF|
|||
|||
  
  
## Table of contents  
  
[1. Overview](#ch1--overview)  
  
  
[1.1. Introduction](#ch1-1--introduction)  
  
  
[1.2. Note](#ch1-2--note)  
  
  
[1.3. Links](#ch1-3--links)  
  
  
[2. Eco.Semaphore1 Component](#ch2--ecosemaphore1-component)  
  
  
[3. IEcoSemaphore1 interface](#ch3--iecosemaphore1-interface)  
  
  
[3.1. IEcoSemaphore1 interface IDL descriptor](#ch3-1--iecosemaphore1-interface-idl-descriptor)  
  
  
[3.1.1. Init function](#ch3-1-1--init-function)  
  
  
[3.1.2.InitWithName function](#ch3-1-2-initwithname-function)  
  
  
[3.1.3.OpenExisting function](#ch3-1-3-openexisting-function)  
  
  
[3.1.4.lose function](#ch3-1-4-lose-function)  
  
  
[3.1.5.Post function](#ch3-1-5-post-function)  
  
  
[3.1.6.Wait function](#ch3-1-6-wait-function)  
  
  
[4. Error codes](#ch4--error-codes)  
  
  
[Appendix A: Training programs](#appendix-a-training-programs)  
  
  
  

# <a id="ch1--overview"></a>1. Overview  
<a id="_Toc179408433"></a>
# <a id="ch1--overview"></a>1. Overview  
This document describes the requirements for the implementation of the Eco.Semaphore1 component.  

# <a id="ch1-1--introduction"></a>1.1. Introduction  
<a id="_Toc179408434"></a>
# <a id="ch1-1--introduction"></a>1.1. Introduction  
Description.  
  

# <a id="ch1-2--note"></a>1.2. Note  
<a id="_Toc179408435"></a>
# <a id="ch1-2--note"></a>1.2. Note  
- Keywords  
  
  

# <a id="ch1-3--links"></a>1.3. Links  
<a id="_Toc179408436"></a>
# <a id="ch1-3--links"></a>1.3. Links  
 This paragraph contains links to information to help you understand this document:   
[] – name of the link  
Available by: <u>http://address</u>  
  

# <a id="ch2--ecosemaphore1-component"></a>2. Eco.Semaphore1 Component  
<a id="_Toc179408437"></a>
# <a id="ch2--ecosemaphore1-component"></a>2. Eco.Semaphore1 Component  

# <a id="ch2--ecosemaphore1-component"></a>2. Eco.Semaphore1 Component  

# <a id="ch2--ecosemaphore1-component"></a>2. Eco.Semaphore1 Component  
  
The Eco.Semaphore1 component   
The component has the following description:  
  
  

# <a id="ch3--iecosemaphore1-interface-"></a>3. IEcoSemaphore1 interface   

# <a id="ch3--iecosemaphore1-interface-"></a>3. IEcoSemaphore1 interface   

# <a id="ch3--iecosemaphore1-interface-"></a>3. IEcoSemaphore1 interface   

# <a id="ch3--iecosemaphore1-interface-"></a>3. IEcoSemaphore1 interface   
  
  

# <a id="ch3-1--iecosemaphore1-interface-idl-descriptor"></a>3.1. IEcoSemaphore1 interface IDL descriptor  

# <a id="ch3-1--iecosemaphore1-interface-idl-descriptor"></a>3.1. IEcoSemaphore1 interface IDL descriptor  
<a id="_Toc179408438"></a>
# <a id="ch3-1--iecosemaphore1-interface-idl-descriptor"></a>3.1. IEcoSemaphore1 interface IDL descriptor  

# <a id="ch3-1--iecosemaphore1-interface-idl-descriptor"></a>3.1. IEcoSemaphore1 interface IDL descriptor  

# <a id="ch3-1--iecosemaphore1-interface-idl-descriptor"></a>3.1. IEcoSemaphore1 interface IDL descriptor  

# <a id="ch3-1--iecosemaphore1-interface-idl-descriptor"></a>3.1. IEcoSemaphore1 interface IDL descriptor  

# <a id="ch3-1--iecosemaphore1-interface-idl-descriptor"></a>3.1. IEcoSemaphore1 interface IDL descriptor  
  
import "IEcoBase1.h"  
[  
object,  
uguid(661C3E2E-7494-4555-B8E1-F82B2C2D3979),  
]  
interface IEcoSemaphore1 : IEcoUnknown {  
  
int16_t	Init	([in] int32_t MaxCount);  
  
int16_t	InitWithName	([in] int32_t MaxCount,  
 [in] char_t* Name);  
  
int16_t	OpenExisting	([in] char_t* Name);  
  
int16_t	Close	();  
  
int32_t	Post	();  
		  
bool_t	Wait	([in] int32_t Milliseconds);  
}		  

# <a id="ch3-1-1--init-function"></a>3.1.1. Init function  
  
The function initializes the unnamed semaphore at the address.  
  

# <a id="ch3-1-2-initwithname-function"></a>3.1.2.InitWithName function  
  
The function   

# <a id="ch3-1-3-openexisting-function"></a>3.1.3.OpenExisting function  
  
The function creates a new POSIX semaphore or opens an existing semaphore.  

# <a id="ch3-1-4-lose-function"></a>3.1.4.lose function  
  
The function closes the named semaphore.  

# <a id="ch3-1-5-post-function"></a>3.1.5.Post function  
  
The function increments (unlocks) the semaphore.  

# <a id="ch3-1-6-wait-function"></a>3.1.6.Wait function  
  
The function decrements (locks) the semaphore.  
  
  
  

# <a id="ch4--error-codes"></a>4. Error codes  
<a id="_Toc179408447"></a>
# <a id="ch4--error-codes"></a>4. Error codes  
  
The following table contains the error codes.  
  
|**Error code**|**Value**|**Description**|
| --- | --- | --- |
|ERR_ECO_SUCCESES|0x0000|Operation successful.|
|ERR_ECO_UNEXPECTED|0xFFFF|Unexpected condition.|
|ERR_ECO_POINTER|0xFFEE|NULL was passed incorrectly for a pointer value.|
|ERR_ECO_NOINTERFACE|0xFFED|No such interface supported.|
|ERR_ECO_COMPONENT_NOTFOUND|0xFFE9|The component was not found.|
||||
||||
  
  
<a id="_Toc164524623"></a><a id="_Toc179408448"></a>
# Appendix A: Training programs  

# Appendix A: Training programs  
  
  

