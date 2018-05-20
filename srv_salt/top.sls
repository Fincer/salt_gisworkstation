base:
  'osfinger:Ubuntu-18.04':
    - match: grain
    - gis_ubuntu-1804
  'os:Windows':
    - match: grain
    - gis_windows
  '*':
    - stone_file