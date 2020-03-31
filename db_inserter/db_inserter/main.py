#!/usr/bin/env python2.7
# -*- coding: utf-8 -*-
"""
Created on Tue Oct 24 15:05:19 2017

@author: rory
"""

import sys
import argparse
import logging 
import os
import json

import lib.funcs
import lib.db_inserter

from kombu import Connection, Exchange, Queue, binding
from kombu.mixins import ConsumerMixin

log = logging.getLogger('main')

def main(args):
    '''
    Setup logging, read config, fire up the Rabbit and Database wrappers and
    then process some messages. Messages come from text file or from web server
    '''
    logging.basicConfig(
        stream=sys.stdout,
        format='%(asctime)s - %(levelname)s - %(name)s - %(message)s',
        #level= log.debug)
        level=getattr(logging, args.loglevel))

    cfg_object = lib.funcs.read_env_vars() 
    log.info('Read config from env vars: %s',cfg_object)

    rabbit_wrapper = lib.funcs.Rabbit_Wrapper(cfg_object, 'Rabbit_DB')

    log.info('Retrieving UDM from queue...')
    exchange = Exchange(cfg_object.get('Rabbit_DB','Source_Topic'), type="topic")
    rabbit_url = rabbit_wrapper.rabbit_url
    topic_binds = []
    keys = json.loads(cfg_object.get('Rabbit_DB','Source_Key'))

    for key in keys:
        log.info('Building queue for topic: %s',key)
        #NOTE: don't declare queue name. It'll get auto generated and expire after 600 seconds of inactivity
        topic_bind = binding(exchange, routing_key=key)
        topic_binds.append(topic_bind)

    queue_name = cfg_object.get('Rabbit_DB','Source_Queue')
    queues = Queue(name=queue_name,
                    exchange=exchange,
                    bindings=topic_binds,
                    max_length = 1000000)

    log.info('Queues: %s',queues)
    with Connection(rabbit_url, heartbeat=20) as conn:
        worker = lib.funcs.Worker(conn, queues, cfg_object)
        worker.run()
    log.warning('Script Ended...')

if __name__ == "__main__":
    '''
    This takes the command line args and passes them to the 'main' function
    '''
    PARSER = argparse.ArgumentParser(
        description='Run the DB inserter')
    PARSER.add_argument(
        '-f', '--folder', help='This is the folder to read.',
        default = None, required=False)
    PARSER.add_argument(
        '-ll', '--loglevel', default='INFO',
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
        help="Set log level for service (%s)" % 'INFO')
    ARGS = PARSER.parse_args()
    try:
        main(ARGS)
    except KeyboardInterrupt:
        log.warning('Keyboard Interrupt. Exiting...')
        os._exit(0)
    except Exception as error:
        log.error('Other exception. Exiting with code 1...')
        log.error(error)
        os._exit(1)