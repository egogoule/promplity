import React, { useState, FormEvent, useEffect, useRef } from 'react';
import { 
  Terminal, 
  FolderOpen, 
  Power, 
  X, 
  Plus, 
  Search, 
  MoreVertical, 
  Server, 
  Clock, 
  ArrowRight,
  ChevronRight,
  Settings
} from 'lucide-react';

// --- TYPES ---
interface Connection {
  id: string;
  ip: string;
  user: string;
  port: number;
  label?: string;
  lastConnected?: string;
}

interface Tab {
  id: string;
  type: 'terminal' | 'sftp';
  title: string;
  subtitle: string;
  connectionId: string;
}

// --- MOCK DATA ---
const INITIAL_SERVERS: Connection[] = [
  { id: '1', ip: '77.110.119.237', user: 'root', port: 22, label: 'Production Defiant', lastConnected: '10m ago' },
  { id: '2', ip: '192.168.1.5', user: 'admin', port: 2222, label: 'Local NAS', lastConnected: '2h ago' },
  { id: '3', ip: '10.0.0.42', user: 'ubuntu', port: 22, label: 'K8s Worker', lastConnected: '5d ago' },
];

const INITIAL_TERMINAL_TEXT = `Welcome to Promplity 1.0.0-lite (GNU/Linux 6.8.0-48-generic x86_64)

 * Documentation:  https://promplity.dev/docs
 * Management:     https://promplity.dev/manage
 * Support:        https://promplity.dev/support

System information as of Mon Jun 1 04:34:28 AM UTC 2026

System load:  0.0               Processes:             116
Usage of /:   13.2% of 29.44GB  Users logged in:       1
Memory usage: 20%               IPv4 address for eth0: 77.110.119.237
Swap usage:   0%

Expanded Security Maintenance for Applications is not enabled.
272 updates can be applied immediately.
To see these additional updates run: apt list --upgradable

Last login: Mon Jun 1 04:28:04 2026 from 5.165.2.61
root@defiant-lime:~# `;

export default function App() {
  const [servers, setServers] = useState<Connection[]>(INITIAL_SERVERS);
  const [tabs, setTabs] = useState<Tab[]>([]);
  const [activeTabId, setActiveTabId] = useState<string | 'HOME'>('HOME');
  
  const [quickConnectInput, setQuickConnectInput] = useState('');
  const [searchQuery, setSearchQuery] = useState('');

  // Auto-scroll terminal hook
  const terminalEndRef = useRef<HTMLDivElement>(null);

  const handleQuickConnect = (e: FormEvent) => {
    e.preventDefault();
    if (!quickConnectInput.trim()) return;
    
    // Parse quick connect input like: ssh user@ip -p port
    // Simple naive parser for demonstration:
    const parts = quickConnectInput.trim().split(' ');
    let user = 'root';
    let ip = quickConnectInput.trim();
    
    if (parts[0] === 'ssh' && parts[1]) {
      ip = parts[1];
    }
    
    if (ip.includes('@')) {
      const split = ip.split('@');
      user = split[0];
      ip = split[1];
    }

    const newTab: Tab = {
      id: `tab-${Date.now()}`,
      type: 'terminal',
      title: ip,
      subtitle: `${user}@${ip}`,
      connectionId: 'quick'
    };

    setTabs([...tabs, newTab]);
    setActiveTabId(newTab.id);
    setQuickConnectInput('');
  };

  const openServer = (server: Connection) => {
    const newTab: Tab = {
      id: `tab-${Date.now()}`,
      type: 'terminal',
      title: server.ip,
      subtitle: `${server.user}@${server.ip}`,
      connectionId: server.id
    };
    setTabs([...tabs, newTab]);
    setActiveTabId(newTab.id);
  };

  const closeTab = (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    const newTabs = tabs.filter(t => t.id !== id);
    setTabs(newTabs);
    if (activeTabId === id) {
      setActiveTabId(newTabs.length > 0 ? newTabs[newTabs.length - 1].id : 'HOME');
    }
  };

  const filteredServers = servers.filter(s => 
    s.ip.includes(searchQuery) || 
    s.user.includes(searchQuery) ||
    s.label?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="flex flex-col h-screen w-full bg-black text-white font-mono selection:bg-white selection:text-black">
      {/* HEADER / TABS BAR */}
      <header className="flex-none flex items-center h-12 border-b border-gray-800 px-4 select-none shrink-0 overflow-x-auto no-scrollbar">
        <div className="flex items-center gap-2 mr-6 text-white font-bold tracking-widest shrink-0 cursor-default">
          <Terminal size={18} className="text-white" strokeWidth={2.5} />
          <span>PROMPLITY</span>
        </div>

        <div className="flex items-center h-full gap-1 overflow-x-auto flex-1">
          <button
            onClick={() => setActiveTabId('HOME')}
            className={`h-full px-4 flex items-center border-b-2 transition-colors shrink-0 ${
              activeTabId === 'HOME' ? 'border-white text-white' : 'border-transparent text-gray-500 hover:text-gray-300'
            }`}
          >
            HOME
          </button>
          
          {tabs.map(tab => (
            <div 
              key={tab.id}
              onClick={() => setActiveTabId(tab.id)}
              className={`h-full flex items-center pl-4 pr-3 border-b-2 transition-colors cursor-pointer shrink-0 max-w-[200px] border-r border-r-gray-900 ${
                activeTabId === tab.id ? 'border-b-white text-white bg-gray-900' : 'border-b-transparent text-gray-500 hover:text-gray-300 hover:bg-gray-900/50'
              }`}
            >
              <div className="truncate text-sm flex-1 mr-3 flex items-center gap-2">
                {tab.type === 'terminal' ? <Terminal size={14} /> : <FolderOpen size={14} />}
                <span className="truncate">{tab.title}</span>
              </div>
              <button 
                onClick={(e) => closeTab(e, tab.id)}
                className="opacity-50 hover:opacity-100 transition-opacity"
              >
                <X size={14} />
              </button>
            </div>
          ))}
        </div>
        
        <div className="shrink-0 ml-4 flex items-center">
             <button className="text-gray-500 hover:text-white p-2">
                 <Settings size={18} />
             </button>
        </div>
      </header>

      {/* MAIN VIEW */}
      <main className="flex-1 overflow-hidden relative">
        {activeTabId === 'HOME' ? (
          <div className="h-full w-full max-w-4xl mx-auto flex flex-col p-8 gap-8 overflow-y-auto">
            
            {/* UNIFIED COMMAND LINE */}
            <div className="flex flex-col gap-2">
              <span className="text-xs text-gray-500 uppercase tracking-widest">Connect</span>
              <form 
                onSubmit={handleQuickConnect}
                className="flex items-center border border-gray-700 bg-black focus-within:border-white transition-colors h-14 px-4"
              >
                <ChevronRight size={20} className="text-gray-500 mr-3" />
                <input 
                  autoFocus
                  type="text" 
                  value={quickConnectInput}
                  onChange={(e) => setQuickConnectInput(e.target.value)}
                  placeholder="ssh user@hostname -p 22"
                  className="flex-1 bg-transparent border-none outline-none text-white font-mono placeholder:text-gray-700 h-full"
                />
                <button type="submit" className="text-gray-500 hover:text-white px-2">
                  <ArrowRight size={20} />
                </button>
              </form>
            </div>

            {/* SAVED SERVERS */}
            <div className="flex flex-col gap-4 mt-4">
              <div className="flex items-center justify-between border-b border-gray-800 pb-2">
                <span className="text-xs text-gray-500 uppercase tracking-widest flex items-center gap-2">
                  <Server size={14} /> 
                  Saved Connections ({filteredServers.length})
                </span>
                
                <div className="flex items-center gap-4">
                  <div className="flex items-center text-gray-500 border-b border-gray-800 focus-within:border-gray-500 focus-within:text-white transition-colors pb-1">
                    <Search size={14} className="mr-2" />
                    <input 
                      type="text" 
                      placeholder="Search..." 
                      className="bg-transparent border-none outline-none text-xs w-32 placeholder:text-gray-700"
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                    />
                  </div>
                </div>
              </div>

              <div className="flex flex-col gap-2">
                {filteredServers.map(server => (
                  <div 
                    key={server.id} 
                    className="group border border-gray-800 hover:border-gray-600 bg-black hover:bg-[#050505] transition-colors p-4 flex items-center justify-between cursor-pointer"
                    onClick={() => openServer(server)}
                  >
                    <div className="flex items-center gap-6">
                      <div className="text-gray-700 group-hover:text-white transition-colors">
                        <Terminal size={24} strokeWidth={1.5} />
                      </div>
                      <div className="flex flex-col">
                        <span className="text-white text-sm font-bold">{server.ip}</span>
                        <span className="text-gray-500 text-xs mt-1">{server.user}@{server.ip}</span>
                      </div>
                      {server.label && (
                        <div className="hidden sm:block ml-4 px-2 py-1 border border-gray-800 text-[10px] text-gray-500 uppercase">
                          {server.label}
                        </div>
                      )}
                    </div>

                    <div className="flex items-center gap-6">
                      <div className="hidden sm:flex items-center text-[10px] text-gray-600 uppercase gap-1">
                        <Clock size={12} />
                        {server.lastConnected}
                      </div>
                      <div className="text-gray-500 text-xs border border-gray-700 px-3 py-1 group-hover:border-white group-hover:text-white transition-colors flex items-center gap-2">
                        <span>CONNECT</span>
                        <ArrowRight size={14} />
                      </div>
                      <button 
                        className="text-gray-600 hover:text-white p-2 rounded transition-colors"
                        onClick={(e) => {
                          e.stopPropagation();
                          // Stop propagation to prevent connection, handle menu
                        }}
                      >
                        <MoreVertical size={16} />
                      </button>
                    </div>
                  </div>
                ))}
                
                {filteredServers.length === 0 && (
                  <div className="text-gray-600 text-sm py-8 text-center border border-dashed border-gray-800">
                    No servers found matching '{searchQuery}'
                  </div>
                )}
              </div>
            </div>
            
          </div>
        ) : (
          /* TERMINAL VIEW */
          <div className="h-full w-full flex flex-col bg-[#050505]">
            {/* Terminal Toolbar */}
            <div className="flex-none h-10 border-b border-gray-800 flex items-center justify-between px-4 bg-black select-none">
              <div className="flex items-center gap-3 text-xs">
                <span className="text-white font-bold">{tabs.find(t => t.id === activeTabId)?.title}</span>
                <span className="text-gray-600">|</span>
                <span className="text-gray-400">{tabs.find(t => t.id === activeTabId)?.subtitle}</span>
                <span className="flex items-center gap-1 text-[10px] text-white tracking-widest uppercase border border-gray-700 px-2 py-0.5 ml-2">
                  <span className="w-1.5 h-1.5 rounded-full bg-white animate-pulse"></span>
                  CONNECTED
                </span>
              </div>
              <div className="flex items-center gap-2">
                <button className="text-gray-500 hover:text-white flex items-center gap-2 text-xs border border-gray-800 hover:border-gray-600 px-3 py-1 transition-colors">
                  <FolderOpen size={14} />
                  <span>SFTP</span>
                </button>
                <button 
                  className="text-gray-500 hover:text-white flex items-center gap-2 text-xs border border-gray-800 hover:border-white px-3 py-1 transition-colors"
                  onClick={(e) => closeTab(e, activeTabId)}
                >
                  <Power size={14} />
                  <span>DISCONNECT</span>
                </button>
              </div>
            </div>

            {/* Terminal Window */}
            <div className="flex-1 p-4 overflow-y-auto text-sm text-gray-300 leading-relaxed font-mono custom-scrollbar">
              <pre className="whitespace-pre-wrap">{INITIAL_TERMINAL_TEXT}
<span className="inline-block w-2.5 h-4 bg-white align-middle animate-pulse ml-0.5"></span></pre>
              <div ref={terminalEndRef} />
            </div>
          </div>
        )}
      </main>

      <style>{`
        .custom-scrollbar::-webkit-scrollbar {
          width: 10px;
          height: 10px;
        }
        .custom-scrollbar::-webkit-scrollbar-track {
          background: #000;
        }
        .custom-scrollbar::-webkit-scrollbar-thumb {
          background: #333;
          border: 2px solid #000;
        }
        .custom-scrollbar::-webkit-scrollbar-thumb:hover {
          background: #555;
        }
        .no-scrollbar::-webkit-scrollbar {
          display: none;
        }
        .no-scrollbar {
          -ms-overflow-style: none;
          scrollbar-width: none;
        }
      `}</style>
    </div>
  );
}
