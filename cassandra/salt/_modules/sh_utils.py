# ============================================================================= 
# _modules/sh_utils.py
# ============================================================================= 
 #!/usr/bin/env python

from jinja2 import Environment, FileSystemLoader

import subprocess, signal, fileinput, os, sys
from shutil import rmtree, ignore_patterns, copyfile, copytree, copystat

def drop_process(proc_name):
  '''Drop the process by process name.'''
  res = True
  pid = 0
  cmd = subprocess.Popen(['ps', 'ax'], stdout=subprocess.PIPE)
  out, err = cmd.communicate()
  for line in out.splitlines():
    if proc_name in line:
      pid = int(line.strip().split(" ", 1)[0])
      try:
        os.kill(pid, signal.SIGKILL)
#       os.waitpid(pid, os.WNOHANG)
      except OSError, e:
        print ("Error: %s - %s." % (e.filename,e.strerror))
        res = False
  if pid == 0:
    print ("Could non find the %s process" % proc_name)
  return res

def remove_file(file_full_name):
  '''Drop file by full file name.'''
  # check if file exists
  if os.path.isfile(file_full_name):
    # if file exists, try to delete it
    try:
      os.remove(file_full_name)
      res = True
    except OSError, e:
      # if failed, report it back to the user
      print ("Error: %s - %s." % (e.filename,e.strerror))
      res = False
  else:    ## Show an error ##
    print("File %s is not found" % file_full_name)
    res = True
  return res


def remove_symlink(file_full_name):
  '''Drop symbolic link.'''
  # check if symlink exists
  if os.path.islink(file_full_name):
    # if symlink exists, try to delete it
    try:
      # Remove the symlink without removing the directory that it links to
      os.unlink(file_full_name)
      res = True
    except OSError, e:
      # if failed, report it back to the user
      print ("Error: %s - %s." % (e.filename,e.strerror))
      res = False
  else:    ## Show an error ##
    print("Symbolic Link %s is not found" % file_full_name)
    res = True
  return res

def remove_tree(dir_path):
  '''Remove directory and all its files.'''
  res = True
  if os.path.exists(dir_path):
    try:
      rmtree(dir_path)
    except OSError, e:
      res = False
      print ("Error: %s - %s." % (e.filename,e.strerror))
  return res

def ignore_patterns(ignore):
  '''Specify some sort of file or directory name as the argument ignore,
    which acts as the filter for names.
    If ignore is in names, then we add it to an ignored_names list that specifies
    to copytree which files or directories to skip.
  '''
  def _ignore_(path, names):
    ignored_names = []
    if ignore in names:
      ignored_names.append(ignore)
    return set(ignored_names)
  return _ignore_

def copy_file (src_path, dst_path):
  '''Copy file.'''
  for file in list_files(src_path):
    if not (file.startswith("_") or file.startswith(".")):
#     print("copying: %s to: %s" % (file, dst_path))
      shutil.copyfile(path.join(src_path, file), path.join(dst_path, file))

def copy_tree(src_path, dst_path, symlinks = False, ignore = None):
  '''Copy an entire directory tree src to a new location dst.
    Example:
      copy_tree(src, dst, ignore=ignore_patterns('*.pyc', 'tmp*'))
  '''
  ## check if destination directory exists
  if not os.path.exists(dst_path):
    os.makedirs(dst_path)
    shutil.copystat(src_path, dst_path)
  try:
    if not ignore:
      shutil.copytree(src_path, dst_path, symlinks, ignore_patterns(ignore))
    else:
      shutil.copytree(src_path, dst_path, symlinks)
  except shutil.Error as e:
    # Directories are the same
    print('Directory not copied. Error: %s' % e)
  except OSError, e:
    # Any error saying that the directory doesn't exist
     print ("Directory not copied. Error: %s." % e)
  return res

def remove_env_variable(file_full_name, var_name):
  '''Remove environment variable from a given file.
  '''
  # check if file exists
  if os.path.isfile(file_full_name):
    for line in fileinput.input(file_full_name, inplace=1):
      row = 'export ' + var_name
      if not line.startswith(row):
        sys.stdout.write(line)
#     else:
#       print('Founded Line is: %s' % line)
  else:    ## Show an error ##
    print("File %s is not found" % file_full_name)
  res = True
  return res

def remove_from_path(file_full_name, statement):
  '''Remove statement from the PATH varible in a given file.
  '''
  # check if file exists
  if os.path.isfile(file_full_name):
    for line in fileinput.input(file_full_name, inplace=1):
      if statement in line:
        line = line.replace(statement,'')
      sys.stdout.write(line)
  else:    ## Show an error ##
    print("File %s is not found" % file_full_name)
  res = True
  return res