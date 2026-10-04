#!/usr/bin/env python3
"""Deterministic LOCAL UI-test fixture. Test-only: no game rules or authentication.

Run this before the opt-in simulator test. The HTTP/WebSocket server binds only
127.0.0.1:39872; it creates ABCD, supports add_bot/start_game, and records /events.
"""
import base64
import hashlib
import json
import os
import struct
import time
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
settings = dict(
    impostors=1,
    minPlayers=2,
    tasksPerPlayer=1,
    killCooldownSec=30,
    roleRevealSec=30,
    gatherTimeoutSec=30,
    discussionSec=30,
    votingSec=30,
    resultSec=5,
    anonymousVotes=False,
    revealRoleOnEject=True,
    emergencyMeetingsPerPlayer=1,
    emergencyCooldownSec=30,
    killDistanceM=2,
    reportDistanceM=3,
    rssiAt1m=-60,
    pathLossExponent=2,
    proximityFreshSec=5,
    checkpointTtlSec=60,
    qrFallback=True,
    devSkipProximity=True,
    devSkipCheckpoint=True,
    ghostTasks=True,
    taskTypes=['wiring'],
    forcedImpostorIds=[],
    uploadSec=5,
    sabotageCooldownSec=30,
    reactorSec=60,
    reactorWindowSec=5,
)
players = []
phase = 'LOBBY'
events = []

def snapshot():
    return dict(
        serverTime=time.time() * 1000,
        code='ABCD',
        mapId='default',
        phase=phase,
        phaseDeadline=time.time() * 1000 + 30000,
        hostId='ben',
        settings=settings,
        stations=[],
        players=players,
        taskProgress=dict(
            done=0,
            total=1,
        ),
        me=dict(
            id='ben',
            name='Ben',
            role='crewmate' if phase != 'LOBBY' else None,
            alive=True,
            isBody=False,
            ackedRole=False,
            bleToken='00000000-0000-0000-0000-000000000001',
            qrToken='test-qr',
            tasks=[],
            lastCheckpoint=None,
            emergencyLeft=1,
            hasVoted=False,
            voteTarget=None,
            killCooldownUntil=None,
            killTargets=[],
            nearbyBodies=[],
            sabotageAvailableAt=None,
        ),
        emergencyAvailableAt=0,
        meeting=None,
        result=None,
        sabotage=None,
        winner=None,
        winReason=None,
    )

def player(id, name, host=False, bot=False):
    return dict(
        id=id,
        name=name,
        isHost=host,
        isBot=bot,
        connected=True,
        alive=True,
        ejected=False,
        role=None,
        hasVoted=False,
    )

class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *args):
        pass

    def json(self, obj):
        data = json.dumps(obj).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        global phase, players
        data = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))))
        events.append(dict(path=self.path, data=data))
        phase = 'LOBBY'
        players = [player('ben', data['name'], True)]
        self.json(dict(code='ABCD', playerId='ben', token='test-token'))

    def do_GET(self):
        global phase, players
        if self.path.startswith('/ws'):
            key = base64.b64encode(hashlib.sha1((self.headers['Sec-WebSocket-Key'] + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
            self.send_response(101)
            self.send_header('Upgrade', 'websocket')
            self.send_header('Connection', 'Upgrade')
            self.send_header('Sec-WebSocket-Accept', key)
            self.end_headers()

            def send(obj):
                data = json.dumps(obj).encode()
                head = bytes([129, len(data)]) if len(data) < 126 else bytes([129, 126]) + struct.pack('!H', len(data))
                self.wfile.write(head + data)
                self.wfile.flush()

            def read(n):
                data = self.rfile.read(n)
                if len(data) != n:
                    raise EOFError
                return data
            try:
                send(dict(type='state', state=snapshot()))
                while True:
                    h = read(2)
                    n = h[1] & 127
                    if n == 126:
                        n = struct.unpack('!H', read(2))[0]
                    elif n == 127:
                        n = struct.unpack('!Q', read(8))[0]
                    mask = read(4) if h[1] & 128 else None
                    data = read(n)
                    if h[0] & 15 == 8:
                        break
                    if mask:
                        data = bytes((x ^ mask[i % 4] for i, x in enumerate(data)))
                    if h[0] & 15 != 1:
                        continue
                    message = json.loads(data)
                    events.append(message)
                    if message['action'] == 'add_bot':
                        players.append(player('bot', 'Test Bot', bot=True))
                    if message['action'] == 'start_game':
                        phase = 'ROLE_REVEAL'
                    if message['action'] == 'ack_role':
                        phase = 'PLAYING'
                    send(dict(type='ack', id=message['id'], ok=True))
                    send(dict(type='state', state=snapshot()))
            except (EOFError, ConnectionError, OSError):
                pass
        elif self.path == '/events':
            self.json(events)
        else:
            self.json(dict(ok=True))
port = int(os.environ.get('LOCAL_LOBBY_TEST_PORT', '39872'))
print(f'Fixture listening on {port}', flush=True)
ThreadingHTTPServer(('127.0.0.1', port), Handler).serve_forever()
