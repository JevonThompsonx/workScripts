@echo off
::	Written by JEG to map to remove all Egnyte drives

cd "C:\Program Files (x86)\Egnyte Connect"
EgnyteClient.exe -command remove -l "ashleyvance"
EgnyteClient.exe -command remove -l "Sun"
EgnyteClient.exe -command remove -l "All Jobs"
EgnyteClient.exe -command remove -l "Library"
EgnyteClient.exe -command remove -l "Templates"
EgnyteClient.exe -command remove -l "Vectorworks"
EgnyteClient.exe -command remove -l "Private"