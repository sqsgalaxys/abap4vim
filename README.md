
ABAP for Vim
============

*I've just started this project on March 12 2013, I'm a new user of Vim, and
I don't have any experience on writing Vim plugins, so if you see something
strange, please let me know*

    *hugo.delacruz[at]live[dot]com[dot]mx

abap4vim is a simple Vim plugin. With this plug-in you can download ABAP code
from your SAP Server, edit the code in Vim, and upload it again to the SAP
Server. This can be helpful for editing ABAP Reports ( No modulpool ), or
simple ABAP programs.

Requirements
------------

### Operating System

This plugin is only tested on Windows 7

### Python

    Python 2.6+

### Easysap/Pysap

Easysap is a wrapper for the Python library pysap, this wrapper let's you
perform Remote Function Calls to a SAP System in an easy way. Both python
modules can be found in the following github repo:

    https://github.com/hugo-dc/easysap

### Python-enabled Vim

    vim --version | grep python

Installation
------------

[pathogen.vim](https://github.com/tpope/vim-pathogen) is the recommended way to
install abap4vim.

    cd ~/vimfiles/bundle
    git clone git@github.com:hugo-dc/abap4vim.git



