{% set cc_version = '2.9.1+git20180223-1' %}
{% set os_version = 'ubuntu-1804' %}

{#
# Things to be considered: https://docs.saltstack.com/en/latest/ref/states/parallel.html
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
  'txt2las'
]
%}

{{ file }}:
  file.managed:
    - name: /usr/local/bin/{{ file }}
    - source: salt://gis_{{ os_version }}/files/lastools/{{ file }}
    - mode: 0755
    - user: root
    - group: root
{% endfor %}

gis_packages:
  pkg.installed:
    - pkgs:
      - gpx2shp
      - rel2gpx
      - quickroute-gps
      - python-gpxpy
      - obdgpslogger
      - merkaartor
      - gpsbabel
      - gpsbabel-gui
      - gis-gps

qgis:
  pkg.installed:
    - pkgs:
      - qgis
      - qgis-server
      - qgis-providers
      - qgis-plugin-grass

gps_daemon:
  pkg.installed:
    - pkgs:
      - gpsd

{#
qgis_conf_script:
  file.managed:
    - name: /tmp/qgisconf.sh
    - source: salt://gis_{{ os_version }}/files/qgisconf.sh
    - require:
      - pkg: qgis

qgis_conf_run:
  cmd.run:
    - name: 'sh /tmp/qgisconf.sh'
    - require:
      - file: qgis_conf_script
#}

qgis_lastools:
  file.managed:
    - name: /usr/share/qgis/python/plugins/processing/algs/lidar/LidarToolsAlgorithmProvider.py
    - source: salt://common/qgis_lastools/LidarToolsAlgorithmProvider.py
    - require:
      - pkg: qgis

cloudcompare_pkg:
  file.managed:
    - name: /tmp/cloudcompare_{{ cc_version }}.deb
    - source: salt://gis_{{ os_version }}/files/cloudcompare_{{ cc_version }}_amd64.deb

cloudcompare_install:
  pkg.installed:
    - sources:
      - cloudcompare: /tmp/cloudcompare_{{ cc_version }}.deb
    - require:
      - file: cloudcompare_pkg
