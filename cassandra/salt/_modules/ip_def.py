# ============================================================================= 
# _modules/ip_def.py
# ============================================================================= 
#!/usr/bin/env python

from jinja2 import Environment, FileSystemLoader

def ip_2_int(ip):
  o = map(int, ip.split('.'))
  res = (16777216 * o[0]) + (65536 * o[1]) + (256 * o[2]) + o[3]
  return res

def int_2_ip(ip_num):
  o1 = int(ip_num / 16777216) % 256
  o2 = int(ip_num / 65536) % 256
  o3 = int(ip_num / 256) % 256
  o4 = int(ip_num) % 256
  return '%(o1)s.%(o2)s.%(o3)s.%(o4)s' % locals()

def grain_ip_2_net():
  ip = str(__grains__['fqdn_ip4']).strip('[]')
  ip_num = ip_2_int(ip.replace("'", ""))
#  print ('ip_num = %s', str(ip_num))
  ip_num = (ip_num >> 8) << 8
  res = int_2_ip(ip_num)
  return res

def if_grain_ip_even():
  ip = str(__grains__['fqdn_ip4']).strip('[]')
#  print ('ip = %s' % ip)
  ip_num = ip_2_int(ip.replace("'", ""))
#  print ('ip_num = %s', str(ip_num))
  if (ip_num % 2 == 0):
    return True
  else:
    return False

# def if_base_ip_even():
#  ip = str(__pillar__['node']['base_ip_address']).strip('[]')
#  print ('ip = %s' % ip)
#  ip_num = ip_2_int(ip.replace("'", ""))
#  print ('ip_num = %s', str(ip_num))
#  if (ip_num % 2 == 0):
#    return True
#  else:
#    return False

def test():
  '''Just a test function'''
  return True

env = Environment(loader=FileSystemLoader('/usr/lib/python2.7/site-packages/salt'))
env.globals['grain_ip_2_net'] = grain_ip_2_net
env.globals['if_grain_ip_even'] = if_grain_ip_even

if __name__ == "__main__":
  test()

  