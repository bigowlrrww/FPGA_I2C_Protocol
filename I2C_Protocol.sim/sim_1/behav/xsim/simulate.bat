@echo off
REM ****************************************************************************
REM Vivado (TM) v2019.1 (64-bit)
REM
REM Filename    : simulate.bat
REM Simulator   : Xilinx Vivado Simulator
REM Description : Script for simulating the design by launching the simulator
REM
REM Generated by Vivado on Mon Nov 18 17:06:30 -0700 2019
REM SW Build 2552052 on Fri May 24 14:49:42 MDT 2019
REM
REM Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
REM
REM usage: simulate.bat
REM
REM ****************************************************************************
echo "xsim I2C_Master_TB_behav -key {Behavioral:sim_1:Functional:I2C_Master_TB} -tclbatch I2C_Master_TB.tcl -view D:/Vivado_Projects/I2C_Protocol/I2C_Master_TB_behav.wcfg -log simulate.log"
call xsim  I2C_Master_TB_behav -key {Behavioral:sim_1:Functional:I2C_Master_TB} -tclbatch I2C_Master_TB.tcl -view D:/Vivado_Projects/I2C_Protocol/I2C_Master_TB_behav.wcfg -log simulate.log
if "%errorlevel%"=="0" goto SUCCESS
if "%errorlevel%"=="1" goto END
:END
exit 1
:SUCCESS
exit 0
