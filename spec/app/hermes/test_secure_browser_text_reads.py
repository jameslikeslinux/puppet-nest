"""Exact nonsecret source reconstruction and selected chrome URL regressions."""
import hashlib
import json
import subprocess

from test_secure_browser_bidi_ui import Browser, load, snapshot
from test_firefox_ui_bridge import load_bridge


def test_chrome_combo_address_is_not_page_supplied():
    bridge = load_bridge()
    class Node:
        def __init__(self, role, name='', text=''):
            self.role, self.name, self.text = role, name, text
        def get_role_name(self):
            return self.role
        def get_name(self):
            return self.name
        def get_child_count(self):
            return 0
    items = [(Node('application'), ()), (Node('frame'), (0,)),
             (Node('tool bar'), (0, 0)),
             (Node('combo box', 'Search with Google or enter address', 'https://fixture.example/chat'), (0, 0, 0)),
             (Node('document web'), (0, 1)),
             (Node('entry', 'Address', 'https://wrong.example/'), (0, 1, 0))]
    bridge._firefox_root = lambda: object()
    bridge._walk = lambda root: iter(items)
    bridge._browser_generation = lambda: 100
    bridge._state_names = lambda node: ['showing', 'visible']
    bridge._extent = lambda node: None
    bridge._text_content = lambda node: node.text
    bridge._firefox_window_id = lambda: '1'
    bridge._run = lambda argv: type('Result', (), {'stdout': b'Fixture - Firefox'})()
    result = bridge._snapshot()
    assert result['url'] == 'https://fixture.example/chat'
    module, legacy = load()
    browser = Browser([{'context': 'fixture', 'url': result['url']}])
    result['tabs'] = [{'selected': True}]
    legacy._with_browser = lambda fn: fn(browser)
    assert module.query(result, 'document.title')['status'] == 'ok'


def test_long_chat_and_exact_multiread_source_checksum():
    module, legacy = load()
    code = ('def greet(value):\n\t# Unicode: 雪 🦉; punctuation: \\" <>&\n'
            '    return "hello: " + value\n\n') * 240
    # Execute the generated fixed observation, not a Python mock of extraction.
    source = '''
const NodeFilter={SHOW_TEXT:4};
const code=__CODE__;
const text={nodeValue:code,parentElement:null};
const pre={textContent:code,isContentEditable:false,parentElement:null,
  matches:()=>false,closest:()=>null,getAttribute:()=>null,labels:[],
  getBoundingClientRect:()=>({width:30,height:20})};
text.parentElement=pre;
const all=Array.from({length:420},(_,i)=>({localName:'p',name:'',id:'',
  isContentEditable:false,parentElement:null,childNodes:[{nodeType:3,textContent:'message '+i}],
  getAttribute:()=>null,closest:()=>null,matches:()=>false,
  getBoundingClientRect:()=>({width:10,height:10,bottom:20,right:20,top:10,left:10})}));
all.push({...all[0],localName:'pre',childNodes:[{nodeType:3,textContent:code}]});
const Node={TEXT_NODE:3};
const document={body:{querySelectorAll:()=>all},querySelectorAll:()=>[pre],
  createTreeWalker:()=>{let done=false;return {nextNode:()=>done?null:(done=true,text)}}};
const performance={timeOrigin:42};
const location={href:'https://fixture.example/shop'};
const getComputedStyle=()=>({display:'block',visibility:'visible'});
const innerHeight=800,innerWidth=1200;
'''.replace('__CODE__', json.dumps(code))
    def execute(script):
        result = subprocess.run(['node', '-e', source + '\nconsole.log(JSON.stringify(' + script + '));'],
                                capture_output=True, text=True, check=True)
        return json.loads(result.stdout)
    offset, tags = 0, []
    while offset is not None:
        page = execute(module._read_script(f'document.domSnapshot({offset})'))
        tags.extend(row['tag'] for row in page['nodes'])
        offset = page['nextOffset']
    assert len(tags) > 350 and tags[-1] == 'pre'
    browser = Browser([{'context': 'fixture', 'url': 'https://fixture.example/shop'}])
    legacy._with_browser = lambda fn: fn(browser)
    module._evaluate = lambda browser, context, script: execute(script)
    cursor, chunks = None, []
    while True:
        page = module.query(snapshot(), 'document.readText("pre",0)', cursor=cursor)
        chunks.append(page['value']['text'])
        assert len(chunks[-1]) <= 4000
        cursor = page['nextCursor']
        assert page['complete'] == (cursor is None)
        if cursor is None:
            break
    assert len(chunks) > 1
    reconstructed = ''.join(chunks)
    assert hashlib.sha256(reconstructed.encode()).hexdigest() == hashlib.sha256(code.encode()).hexdigest()
    assert reconstructed == code
    print('SHA256 exact source:', hashlib.sha256(reconstructed.encode()).hexdigest())


def test_text_cursor_rejects_navigation_generation_tab_and_content_changes():
    module, legacy = load()
    browser = Browser([{'context': 'fixture', 'url': 'https://fixture.example/shop'}])
    legacy._with_browser = lambda fn: fn(browser)
    raw = {'text': 'ordinary source\n' * 700, 'total': 1, 'epoch': 42, 'url': 'https://fixture.example/shop'}
    module._evaluate = lambda *args: dict(raw)
    first = module.query(snapshot(), 'document.readText("pre",0)')
    cursor = first['nextCursor']
    assert cursor
    for ui, change in [(dict(snapshot(), browser_generation=101), {}),
                       (snapshot(), {'epoch': 43}), (snapshot(), {'text': 'changed'}),
                       (snapshot(), {'url': 'https://fixture.example/new'})]:
        old = dict(raw)
        raw.update(change)
        try:
            module.query(ui, 'document.readText("pre",0)', cursor=cursor)
        except ValueError as exc:
            assert 'stale' in str(exc)
        else:
            raise AssertionError('stale text cursor accepted')
        raw.clear()
        raw.update(old)
    for tabs in ([], [{'selected': False}], [{'selected': True}, {'selected': True}]):
        try:
            module.query(dict(snapshot(), tabs=tabs), 'document.title')
        except RuntimeError:
            pass
        else:
            raise AssertionError('unselected or ambiguous tabs accepted')


def test_text_redaction_precedes_chunking():
    module, legacy = load()
    browser = Browser([{'context': 'fixture', 'url': 'https://fixture.example/shop'}])
    legacy._with_browser = lambda fn: fn(browser)
    module._evaluate = lambda *args: {'text': 'x' * 3998 + ' 847261 user@example.test\n', 'total': 1, 'epoch': 1, 'url': 'https://fixture.example/shop'}
    first = module.query(snapshot(), 'document.readText("pre",0)')
    second = module.query(snapshot(), 'document.readText("pre",0)', cursor=first['nextCursor'])
    text = first['value']['text'] + second['value']['text']
    assert '847261' not in text and 'user@example.test' not in text
    assert first['redacted'] and second['redacted']


def test_cursor_survives_new_bidi_session_context_ids_for_same_visible_tab():
    module, legacy = load()
    browser = Browser([{'context': 'session-one', 'url': 'https://fixture.example/shop'}])
    legacy._with_browser = lambda fn: fn(browser)
    module._evaluate = lambda *args: {'text': 'safe source\n' * 700, 'total': 1, 'epoch': 42, 'url': 'https://fixture.example/shop'}
    first = module.query(snapshot(), 'document.readText("pre",0)')
    browser.contexts[0]['context'] = 'session-two'
    second = module.query(snapshot(), 'document.readText("pre",0)', cursor=first['nextCursor'])
    assert second['revision'] == first['revision']
    assert second['value']['offset'] == 4000


def test_direct_text_excludes_protected_descendants_and_rejects_executable_input():
    module, _ = load()
    script = module._read_script('document.readText("pre",0)')
    setup = '''
const NodeFilter={SHOW_TEXT:4};
const performance={timeOrigin:1},location={href:'https://fixture.example/'};
const getComputedStyle=e=>({display:e.hidden?'none':'block',visibility:'visible'});
const make=(opts={})=>({name:'',id:'',labels:[],parentElement:null,
  getAttribute:()=>null,matches:()=>false,...opts});
const root=make(), password=make({name:'password',parentElement:root}),
  hidden=make({hidden:true,parentElement:root}), editable=make({isContentEditable:true,parentElement:root}),
  control=make({matches:s=>s.includes('input'),parentElement:root}),
  marked=make({matches:s=>s.includes('[data-sensitive=true]'),parentElement:root});
const texts=[{nodeValue:'  safe\\n\\t雪 🦉',parentElement:root},
  ...[password,hidden,editable,control,marked].map(parentElement=>({nodeValue:'NEVER_EXPORT',parentElement}))];
const document={querySelectorAll:()=>[root],createTreeWalker:()=>{let i=0;return {nextNode:()=>texts[i++]||null}}};
'''
    result = subprocess.run(['node', '-e', setup + '\nconsole.log(JSON.stringify(' + script + '));'],
                            capture_output=True, text=True, check=True)
    value = json.loads(result.stdout)
    assert value['text'] == '  safe\n\t雪 🦉' and value['redacted']
    for bad in ('document.readText("pre",0);alert(1)', 'document.readText("input[type=password]",0)',
                'document.readText("pre",-1)', 'document.readText("pre",01)'):
        try:
            module._read_script(bad)
        except ValueError:
            pass
        else:
            raise AssertionError('unsafe read accepted')
    for expression in ('document.title', 'document.readText("pre",0)'):
        module, legacy = load()
        browser = Browser([{'context': 'fixture', 'url': 'https://fixture.example/shop'}])
        legacy._with_browser = lambda fn: fn(browser)
        module._evaluate = lambda *args: {'text': 'safe', 'epoch': 1, 'url': 'https://fixture.example/shop'}
        try:
            module.query(snapshot(), expression, snapshot_reader=lambda: dict(snapshot(), browser_generation=101))
        except RuntimeError as exc:
            assert 'changed during observation' in str(exc)
        else:
            raise AssertionError('changed browser read exported')


if __name__ == '__main__':
    for name, fn in list(globals().items()):
        if name.startswith('test_'):
            fn()
            print('PASS', name)
