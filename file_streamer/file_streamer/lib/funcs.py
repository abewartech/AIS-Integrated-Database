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
    CFG['file_sleep'] = os.getenv('WAIT_BETWEEN_FILES')
    CFG['file_folder'] = os.getenv('CONTAINER_FILE_DIR')
    CFG['exchange'] = os.getenv('RABBIT_EXCHANGE')
    # CFG[''] = os.getenv('')
    log.info(CFG)
    return CFG

class Rabbit_Wrapper(object):
    '''
    Take each message and do something with it.
    Send the decoded messages to a rabbit broker
    '''
    def __init__(self, cfg_object):
        '''
        setup all the goodies
        '''
        log.debug('Setting up RabbitMQ interface...')

        user = cfg_object.get('rabbit_user')
        password = cfg_object.get('rabbit_pw')
        host = cfg_object.get('rabbit_host')
        port = cfg_object.get('rabbit_port')
        sink_topic_exchange_name= cfg_object.get('exchange')
 
        # Key to consume from:
        self.rabbit_url = "amqp://{0}:{1}@{2}:{3}/".format(user, password, host, port)
        log.debug('Rabbit is at {0}'.format(self.rabbit_url))
        self.sink_topic_exchange = Exchange(sink_topic_exchange_name, type="topic")
        self.conn = Connection(self.rabbit_url)
        self.sink = Producer(exchange=self.sink_topic_exchange,
                              channel=self.conn,
                              serializer ='json')
        log.info('Rabbit Wrapper initialised.')

    def errback(self, exc, interval):
        log.warning('Produce error: %r', exc)
        log.warning('Retry in %s +1  seconds.', interval)
        time.sleep(float(interval)+1)

    def produce_msg(self, msg_dict):
        '''
        send the info to all the right places
        '''
        payload = msg_dict
        payload_routing_key = msg_dict['routing_key']
        producer = self.conn.ensure(self.sink, self.sink.publish, errback=self.errback, interval_start = 1.0)
        producer(payload, routing_key=payload_routing_key)
        log.debug(' -Sent to Rabbit exchange: %s >> %s',self.sink_topic_exchange, payload_routing_key)




# IS this still needed?

class Master_AIS_Dict():
    '''
    Contains all the possible AIS fields and the database column related to it.
    '''
    def __init__(self):
        self.AIS_to_DB = {'decoding_Lib':'LibAIS',
                                        'band_flag':None,
                                        'callsign':'callsign',
                                        'cog':'cog',
                                        'commstate_cs_fill':None,
                                        'commstate_flag':None,
                                        'day':None,
                                        'dim_a':'to_bow',
                                        'dim_b':'to_stern',
                                        'dim_c':'to_port',
                                        'dim_d':'to_starboard',
                                        'display_flag':None,
                                        'dsc_flag':None,
                                        'fix_type':None,
                                        'hour':None,
                                        'id':None,
                                        'keep_flag':None,
                                        'm22_flag':None,
                                        'minute':None,
                                        'mmsi':'mmsi',
                                        'mode_flag':None,
                                        'month':None,
                                        'nav_status':'navigation_status',
                                        'part_num':None,
                                        'position_accuracy':None,
                                        'raim':None,
                                        'received_stations':None,
                                        'repeat_indicator':None,
                                        'reservations':None,
                                        'rot':'rot',
                                        'rot_over_range':None,
                                        'second':None,
                                        'slot_increment':None,
                                        'slot_number':None,
                                        'slot_offset':None,
                                        'slot_timeout':None,
                                        'slots_to_allocate':None,
                                        'sog':'sog',
                                        'spare':None,
                                        'spare2':None,
                                        'special_manoeuvre':None,
                                        'sync_state':None,
                                        'timestamp':None,
                                        'transmission_ctl':None,
                                        'true_heading':'true_heading',
                                        'type_and_cargo':'type_and_cargo',
                                        'unit_flag':None,
                                        'utc_hour':None,
                                        'utc_min':None,
                                        'utc_spare':None,
                                        'vendor_id':None,
                                        'longitude':'longitude',
                                        'x':'longitude',
                                        'latitude':'latitude',
                                        'y':'latitude',
                                        'year':None,
                                        'destination': 'destination',
                                        'name': 'name',
                                        'eta_hour': 'eta_hour',
                                        'ais_version': None,
                                        'draught': 'draught',
                                        'eta_day': 'eta_day',
                                        'eta_minute': 'eta_minute',
                                        'eta_month': 'eta_month',
                                        'imo_num': 'imo',
                                        'server_timestamp':'server_timestamp',
                                        'event_time':'event_time',
                                        'database_id':'database_id',
                                        'routing_key':'routing_key',
                                        'message_type':'message_type'}


    def AisDict_to_DbDict(self, AIS_dict):
        DbDict = {}
        for key, value in AIS_dict.items():
            try:
                if self.AIS_to_DB[key] is None:
                    pass
                else:
                    DbDict[self.AIS_to_DB[key]] = value
            except:
                pass
 
        if 'to_bow' in DbDict.keys():
            try:
                DbDict['length'] = float(DbDict['to_bow']) + float(DbDict['to_stern'])
                DbDict['width'] = float(DbDict['to_port']) + float(DbDict['to_starboard'])
#                DbDict.pop('to_bow')
            except Exception as err:
                print('Error with :' + str(err))

        return DbDict

class AIS_MSG:
    def __init__(self, data= None, multi=False):
        self.valid_decode = False
        self.multi = multi

        if type(data) == list:
            if multi:
                #multiline_message
                try:
                    decoder_to_use = 'libais'
                    self.raw_line = data[0] # Raw NMEA string
                    self.raw_line2 = data[1] # Raw NMEA string
                    self.decoder = decoder_to_use
                    self.decode_multi()
                    self.valid_decode = True

                except Exception as err:
                    log.error('Failed to decode: %s', data)
                    log.error(err)
                    self.valid_decode = False
                    pass

        if type(data) == str:
            '''
            Assume it's a raw nmea string
            '''

            try:
                decoder_to_use = 'libais'
                self.raw_line = data # Raw NMEA string
                self.decoder = decoder_to_use
                self.decode()
                if type(self.decoded_msg) == dict:
                    self.valid_decode = True

            except Exception as err:
                log.debug('NMEA Constructor failed')
                log.debug(err)
                log.debug(data)
                self.valid_decode = False
                pass


    def decode(self):

        msg_split = self.raw_line.split(',')

        if msg_split[0].startswith('!A') or msg_split[0].startswith('!B'):
            self.identifier = msg_split[0] # NMEA identifier !AIVDM or ! !ADVDO etc
            self.code_fragments = self.mk_int(msg_split[1]) # the count of fragments in the currently accumulating message.
            self.fragment_number = self.mk_int(msg_split[2]) # number of fragment in sequence
            self.message_sequence_id = self.mk_int(msg_split[3]) #is a sequential message ID for multi-sentence messages.
            self.rf_channel_code = msg_split[4] # A or B in AIS
            self.payload = msg_split[5] #The data
            self.padding = int(msg_split[6].split('*')[0]) #Number of padding bits after payload
            self.checksum = msg_split[6].split('*')[1] #NMEA checksum
            self.decoded_time = datetime.datetime.now(pytz.utc)
            try:
                self.decoded_msg = AIS_Decoder(self.payload, self.padding,decoder = self.decoder)
                self.decoded_msg['server_timestamp'] = self.decoded_time.isoformat()
                self.decoded_msg['message_type'] = 'ais'
                self.decoded_msg['routing_key'] = 'ais.tnpa'
                self.decoded_msg['mmsi'] = str(self.decoded_msg.get('mmsi'))
                self.decoded_msg['imo'] = str(self.decoded_msg.get('imo'))
                self.decoded_msg['database_id'] = str(self.decoded_msg.get('mmsi'))
            except Exception as err:
                try:
                    pad_len = 71 - len(self.payload)
                    payload = self.payload + pad_len*'8'
                    padding = 2
                    self.decoded_msg = AIS_Decoder(payload, padding, decoder = self.decoder)
                    self.decoded_msg['server_timestamp'] = self.decoded_time.isoformat()
                    self.decoded_msg['message_type'] = 'ais'
                    self.decoded_msg['routing_key'] = 'ais.tnpa'
                    self.decoded_msg['mmsi'] = str(self.decoded_msg.get('mmsi'))
                    self.decoded_msg['imo'] = str(self.decoded_msg.get('imo'))
                    self.decoded_msg['database_id'] = str(self.decoded_msg.get('mmsi'))
                except Exception as err:
                    log.debug('Single line decode error: %s',err)



        else:
            self.decoded_msg = ''
            self.padding = ''

    def decode_multi(self):
        msg1_split = self.raw_line.split(',')
        msg2_split = self.raw_line2.split(',')

        if msg1_split[0].startswith('!A') or msg1_split[0].startswith('!B'):
            self.identifier = msg1_split[0] # NMEA identifier !AIVDM or ! !ADVDO etc
            self.code_fragments = self.mk_int(msg1_split[1]) # the count of fragments in the currently accumulating message.
            self.fragment_number = self.mk_int(msg1_split[2]) # number of fragment in sequence
            self.message_sequence_id = self.mk_int(msg1_split[3]) #is a sequential message ID for multi-sentence messages.
            self.rf_channel_code = msg1_split[4] # A or B in AIS

            self.checksum = msg1_split[6].split('*')[1] #NMEA checksum
            self.decoded_time = datetime.datetime.now(pytz.utc)
            self.payload = msg1_split[5] + msg2_split[5] #The data
            self.padding = int(msg2_split[6].split('*')[0]) #Number of padding bits after payload
            try:
                self.decoded_msg = AIS_Decoder(self.payload, self.padding,decoder = self.decoder)
                self.decoded_msg['server_timestamp'] = self.decoded_time.isoformat()
                self.decoded_msg['message_type'] = 'ais'
                self.decoded_msg['database_id'] = str(self.decoded_msg.get('mmsi'))
                self.decoded_msg['mmsi'] = str(self.decoded_msg.get('mmsi'))
                self.decoded_msg['routing_key'] = 'ais.tnpa'
            except Exception as err:
                log.debug('Multi line decode error: %s',err)


        else:
            self.decoded_msg = ''
            self.padding = ''

    def mk_int(self, s):
        s = s.strip()
        return int(s) if s else 0

