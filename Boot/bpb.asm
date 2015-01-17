%define boot_sector				0x7c00

%define bpbOEM					boot_sector + 0x03
%define bpbBytesPerSector  		boot_sector + 0x0b
%define bpbSectorsPerCluster	boot_sector + 0x0d
%define bpbReservedSectors		boot_sector + 0x0e
%define bpbNumberOfFATs			boot_sector + 0x10
%define bpbRootEntries			boot_sector + 0x11
%define bpbTotalSectors			boot_sector + 0x13
%define bpbMedia				boot_sector + 0x15
%define bpbSectorsPerFAT		boot_sector + 0x16
%define bpbSectorsPerTrack		boot_sector + 0x18
%define bpbHeadsPerCylinder		boot_sector + 0x1a
%define bpbHiddenSectors		boot_sector + 0x1c
%define bpbTotalSectorsBig		boot_sector + 0x20
%define bsDriveNumber			boot_sector + 0x24
%define bsUnused				boot_sector + 0x25
%define bsExtBootSignature		boot_sector + 0x26
%define bsSerialNumber			boot_sector + 0x27
%define bsVolumeLabel			boot_sector + 0x2b
%define bsFileSystem			boot_sector + 0x36