#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use_ok('Locale::POFileManager')
    or BAIL_OUT("couldn't load Locale::POFileManager");
use_ok('Locale::POFileManager::File')
    or BAIL_OUT("couldn't load Locale::POFileManager::File");

done_testing;
