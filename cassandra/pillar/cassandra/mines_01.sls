mine_functions:
  get_publicip:
    - mine_function: grains.get
    - public_ip
  get_privateip:
    - mine_function: grains.get
    - private_ip
