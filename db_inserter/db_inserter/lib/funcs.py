#!/usr/bin/env python2
# -*- coding: utf-8 -*-
"""
Created on Wed Mar 29 12:15:15 2017

@author: rory
""" 
import logging
import logging.handlers
import time
import os
import subprocess
import json
import datetime
import pytz
 
from kombu import Connection, Exchange, Producer, Queue


log = logging.getLogger('main.funcs') 

def read_env_vars():
    '''
    Read environ variables and return as dict. 

    This is to replace the config file function in preperation for rancher, where all config is handled by env vars.
    '''
    log.debug('Reading environment variables...')
    CFG = {}
    CFG['rabbit_port'] = os.getenv('RABBIT_MSG_PORT')
    CFG['rabbit_user'] = os.getenv('RABBITMQ_DEFAULT_USER')
    CFG['rabbit_pw'] = os.getenv('RABBITMQ_DEFAULT_PASS')
    CFG['rabbit_host'] = os.getenv('RABBIT_HOST')
    CFG['routing_key'] = os.getenv('SOURCE_RKEY')
    CFG['insert_period'] = os.getenv('INSERT_PERIOD')
    CFG['file_folder'] = os.getenv('CONTAINER_FILE_DIR')
    CFG['exchange'] = os.getenv('RABBIT_TOPIC')
    # CFG[''] = os.getenv('')
    log.info(CFG)
    return CFG
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Sep  4 10:21:24 2017

Gets VMS data and sends it to a RabbitMQ docker. Data comes from VMS port or
else from a logfile.

@author: rory
"""
import sys
import argparse
import logging
import configparser
import datetime
from kombu import Connection, Exchange, Queue, binding
from kombu.mixins import ConsumerMixin
import json
import psycopg2
import traceback
import helper_classes
import sql_builder

log = logging.getLogger(__name__)

def read_config(cfg_file):
    '''
    same as the hudred other instances of this function
    '''
    CFG = configparser.ConfigParser()
    CFG.read(cfg_file)
    return CFG

class Worker(ConsumerMixin):
    def __init__(self, conn, queues, cfg):
        log.info('Starting up Rabbit Consumer')
        self.connection = conn
        self.config = cfg
        self.queue = queues

        self.pos_reports = []
        self.voy_reports = []
        self.vms_reports = []
        self.sar_images = []
        self.sar_vessels = []
        self.sar_bilges = []
        self.time_of_process = datetime.datetime.now()
        log.info('Time started: %s',self.time_of_process)
#        self.db_wrapper = helper_classes.Database_Wrapper(cfg)
        self.process_period = self.config.get('Database', 'InsertPeriod')
        log.info('Bulk inserting every %s seconds',self.process_period)
        log.info('Rabbit Consumer started...')

        log.info('Target DB is %s at %s',self.config.get('Database', 'Database'),self.config.get('Database', 'Host'))
        conn = psycopg2.connect(host=self.config.get('Database', 'Host'),
                                 dbname=self.config.get('Database', 'Database'),
                                 port=self.config.get('Database', 'Port'),
                                 user=self.config.get('Database', 'User'),
                                 password=self.config.get('Database', 'Pass'))

        self.cursor = conn.cursor()


    def get_consumers(self, Consumer, channel):
        return [
            Consumer(self.queue, callbacks=[self.on_message], accept=['json']),
        ]

    def bulk_process_to_db(self):
        try:
            sql_builder.insert_into_pos_table(self.pos_reports, self.config)
        except Exception as error:
            log.error('Issue with bulk pos table DB process')
            log.error(error)
        try:    
            sql_builder.insert_into_voy_table(self.voy_reports, self.config)
        except Exception as error:
            log.error('Issue with bulk voy table DB process')
            log.error(error)
        try:
            sql_builder.insert_into_vms_table(self.vms_reports, self.config)
        except Exception as error:
            log.error('Issue with bulk vms DB process')
            log.error(error)
        try:
            sql_builder.insert_into_sar_ves_table(self.sar_vessels, self.config)
        except Exception as error:
            log.error('Issue with bulk sar vessel DB process')
            log.error(error)
        try:
            sql_builder.insert_into_sar_img_table(self.sar_images, self.config)
        except Exception as error:
            log.error('Issue with bulk sar img DB process')
            log.error(error)
        try:
            sql_builder.insert_into_sar_oil_table(self.sar_bilges, self.config)
            
        except Exception as error:
            log.error('Issue with bulk oil DB process')
            log.error(error)

        finally:
            self.pos_reports = []
            self.voy_reports = []
            self.vms_reports = []
            self.sar_images = []
            self.sar_vessels = []
            self.sar_bilges = []
            self.time_of_process = datetime.datetime.now()

    def unknown_to_dict_list(self,body):

        msg_dict_list = [{}]

        if type(body) is str:
            msg = json.loads(body)
            if type(msg) is list:
                msg_dict_list = msg
            elif type(msg) is dict:
                msg_dict_list = [msg]
            else:
                log.warning('Unconverted str in dict_list: %s',body)
        elif type(body) is dict:
            msg_dict_list = [body]
        elif type(body) is list:
            msg_dict_list = body
        elif body is None:
            log.warning('None-type in dict_list: %s',body)
        else:
            log.warning('Unconverted kak in dict_list: %s',body)

        return msg_dict_list
    
    def handle_ais(self, msg):
        ais_type = str(msg.get('id'))
        if ais_type in ['1','2','3','18'] or 'latitude' in msg:
            self.pos_reports.append(msg)
        elif ais_type in ['5','24'] or 'name' in msg or 'class_and_cargo' in msg:
            self.voy_reports.append(msg)
        elif ais_type in ['19']:
            self.pos_reports.append(msg)
            self.voy_reports.append(msg)
        else:
            log.info('NMFPM: %s',msg)
        return
    
    def handle_UDM_JSON_ais(self, msg):
        ais_type = str(msg.get('id'))
        msg_format = str(msg.get('format'))
        
        if msg_format == 'UDM_JSON':
            #ARNO Style UDM
            if not msg.get('pos_filter'):
                #MSG not filtered because of pos report
                self.pos_reports.append(msg)
            elif not msg.get('voy_filter'):
                self.voy_reports.append(msg)
        else:
            # Rory Style UDM
            if ais_type in ['1','2','3','18'] or 'latitude' in msg:
                self.pos_reports.append(msg)
            elif ais_type in ['5','24'] or 'name' in msg or 'class_and_cargo' in msg:
                self.voy_reports.append(msg)
            elif ais_type in ['19']:
                self.pos_reports.append(msg)
                self.voy_reports.append(msg)
            else:
                log.info('NMFPM: %s',msg)
        return

    def handle_vms(self, msg):
        self.vms_reports.append(msg)                
        return
    
    def handle_sar_vessel(self, msg):
        self.sar_vessels.append(msg)        
        return
    
    def handle_sar_image(self, msg):
        self.sar_images.append(msg)        
        return
    
    def handle_sar_bilge(self, msg):
        self.sar_bilges.append(msg)        
        return
    
    
    
    def on_message(self, body, message):
        log.debug('Msg type %s received: %s',type(body),body)
        if message.delivery_info['redelivered']:
            message.reject()
            return
        else:
            message.ack()
            
        msg_dict_list = self.unknown_to_dict_list(body)
        try:
            for msg in msg_dict_list:
                routing_key = msg.get('routing_key')
                routing_key = routing_key.split('.')
                data_type = routing_key[3]
                if data_type == 'ais':
                    self.handle_ais(msg)
                elif data_type == 'vms':
                    self.handle_vms(msg)
                elif routing_key[1] == 'sar':
                    subtype = routing_key[4]
                    if subtype == 'vessel':
                        self.handle_sar_vessel(msg)
                    elif subtype == 'image':
                        self.handle_sar_image(msg)
                    elif subtype == 'bilge':
                        self.handle_sar_bilge(msg)
                    
        except Exception as err:
                log.error('Error in handling message')
                log.error('MSG type: %s',type(body))
                log.error('MSG: %s',body)

        time_now = datetime.datetime.now()
        if (time_now - self.time_of_process).seconds > int(self.process_period):
            log.info('Starting bulk DB update')
            num_msgs = len(self.pos_reports) + len(self.voy_reports)
            self.bulk_process_to_db()
            time_now_now = datetime.datetime.now()
            log.info('Bulk DB update complete: %s secs for %s messages.',(time_now_now - time_now).seconds, num_msgs)
            self.time_of_process = time_now_now
  