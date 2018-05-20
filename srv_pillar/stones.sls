{% if grains['kernel'] == 'Linux' %}
mysterystone: ocean pearl & fishy cochlea
location: /tmp/my_precious
{% elif grains['kernel'] == 'Windows' %}
mysterystone: sharp glass fragments from a shattered window
location: 'C:\stone.txt'
{% else %}
mysterystone: 9 55 N 115 32 E
location: unknown
{% endif %}