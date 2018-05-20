put_stone:
  file.managed:
    - name: {{ pillar['location'] }}
    - source: salt://stone_file/granite.txt
    - template: jinja
