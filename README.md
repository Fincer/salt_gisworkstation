# SaltStack - GIS workstation setup
Set up GIS software on multiple computers simultaneosly.

This repository relies heavily on SaltStack. For further information about SaltStack, please take a look on [SaltStack website](https://saltstack.com/).

Tested with Salt Master 2018.3 & Salt Minions 2018.3 (x64).

## About

This repository installs several GIS programs to multiple computers. This software includes:

- [LASTools](https://rapidlasso.com/lastools/)

- [QGIS](https://qgis.org)

- [CloudCompare](http://cloudcompare.org/)

- [gpsbabel](gpsbabel.org)

- [Merkaartor](merkaartor.be)

- [QuickRoute](http://www.matstroeng.se/quickroute/en/)

- etc.

## Usage

```
git clone https://github.com/Fincer/salt_gisworkstation
cd salt_gisworkstation
sudo bash runme.sh

```

## Notes!

- Works currently only on the following environments:

    - Ubuntu 18.04 LTS & variants

    - Microsoft Windows (main version 7 tested, 64-bit)
    
- Requires preconfigured Salt minion computers (for now) and established connection between the master computer and minions

- Master computer requires Ubuntu 18.04 LTS (or variant)

## Sample images

The following images are for demonstration purposes only.

---------------------

### MS Windows 7 minion after software installation

![windows_1](https://raw.githubusercontent.com/Fincer/salt_gisworkstation/master/sample_images/screen_windows-final.png)

![windows_2](https://raw.githubusercontent.com/Fincer/salt_gisworkstation/master/sample_images/screen_windows-final-2.png)

---------------------

### Lubuntu 18.04 LTS master after software installation

![ubuntu_master](https://raw.githubusercontent.com/Fincer/salt_gisworkstation/master/sample_images/screen_ubuntu-master-final.png)

---------------------

### Lubuntu 18.04 LTS minion after software installation

![ubuntu_minion](https://raw.githubusercontent.com/Fincer/salt_gisworkstation/master/sample_images/screen_ubuntu-final.png)

---------------------

## License

This repository uses GPLv3 license. Please see [LICENSE](https://github.com/Fincer/salt_gisworkstation/blob/master/LICENSE) files for details.
