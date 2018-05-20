{% set qgis_version = '2.18' %}
{% set os_version = 'windows' %}

{#
# Things to be considered: https://docs.saltstack.com/en/latest/ref/states/parallel.html
#}

{# 
# LASTools: Works OK 
#}
{% for file in [
  'las2las',
  'las2txt',
  'lasdiff',
  'lasindex',
  'lasinfo',
  'lasmerge',
  'lasprecision',
  'laszip',
  'txt2las',
  'blast2dem',
  'blast2iso',
  'bytecopy',
  'bytediff',
  'e572las',
  'las2dem',
  'las2iso',
  'las2shp',
  'las2tin',
  'lasboundary',
  'lascanopy',
  'lasclassify',
  'lasclip',
  'lascolor',
  'lascontrol',
  'lascopy',
  'lasduplicate',
  'lasgrid',
  'lasground',
  'lasground_new',
  'lasheight',
  'laslayers',
  'lasnoise',
  'lasoptimize',
  'lasoverage',
  'lasoverlap',
  'lasplanes',
  'laspublish',
  'lasreturn',
  'lassort',
  'lassplit',
  'lasthin',
  'lastile',
  'lastool',
  'lastrack',
  'lasvalidate',
  'lasview',
  'lasvoxel',
  'shp2las',
  'sonarnoiseblaster'
]
%}

{{ file }}:
  file.managed:
    - makedirs: True
    - name: 'C:\lastools\{{ file }}.exe'
    - source: 'salt://gis_{{ os_version }}/files/lastools/{{ file }}.exe'

{% endfor %}

{# 
# GPX2SHP: Works OK
#}
put_gpx2shp.exe:
  file.managed:
    - name: 'C:\lastools\gpx2shp.exe'
    - source: 'salt://gis_{{ os_version }}/files/gpx2shp.exe'

{#
# Installation of Windows programs with Salt is not as good as on Linux minions
# Many installation processes seem not to report about their statuses back to the
# Salt minion process, thus making Salt master to think that the minion
# computer doesn't return anything. Therefore, some custom approaches
# for installing Windows software on Salt minion must be taken for now
#}

{#
# QuickRoute: installs OK - NOTE: retcode 2 (Error), install_status: success
#}
install_quickroute:
  pkg.installed:
    - pkgs:
      - quickroute-gps_x86

{#
# Merkaartor: Installs OK - NOTE: retcode 2 (Error), install_status: success
#}
install_merkaartor:
  pkg.installed:
    - pkgs:
      - merkaartor

{#
# CloudCompare: Installs OK although takes time
#}
install_cloudcompare:
  pkg.installed:
    - pkgs:
      - cloudcompare

{#
# GPSd: Silent installer complaints about missing serial port, thus hanging the Salt state execution
# Disable the package installation until solution is found
#install_gpsd:
#  pkg.installed:
#    - pkgs:
#      - gpsd

# QGIS: Installs OK although takes A LOT OF time
# Requires increased timeout in salt command on Salt master computer
# until better support for NSIS installers have been implemented in Saltstack
#
# See runme.sh for further information 

# The installer does not work as well as CloudCompare's installer
# This is not a good workaround but better than nothing
# Without it, the state hangs here forever until timeout is reached when 
# re-running the installation:
#}

{% if not salt['file.directory_exists']('C:\Program Files\QGIS ' + qgis_version) %}

install_qgis_pkg:
  pkg.installed:
    - pkgs:
      - qgis

{% endif %}

{#
# At launch, QGIS tends to complaint about SSL. Fix this by doing the following.
#}
fix_qgis_ssl:
  cmd.run:
    - shell: powershell
    - name: '(New-Object System.Net.WebClient).DownloadString("https://ubuntu.qgis.org/version.txt")'

qgis_lastools:
  file.managed:
    - name: C:\Program Files\QGIS {{ qgis_version }}\apps\qgis-ltr\python\plugins\processing\algs\lidar\LidarToolsAlgorithmProvider.py
    - source: salt://common/qgis_lastools/LidarToolsAlgorithmProvider.py

{#
# Technically the following should be required, but qgis installation status retcode is always 2 (failure) although
# returned string states: 'install_status: success' and installation can be confirmed on the minion computer
# This is likely a bug in Saltstack because it happens on multiple Windows NSIS installer packages
#    - require:
#      - pkg: install_qgis_pkg
#}
