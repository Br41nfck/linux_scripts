#!/usr/bin/env python3

import os
import sys
import threading
import subprocess
import time
import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext, filedialog


def find_autotest_script() -> str:
    here = os.path.abspath(os.path.dirname(__file__))
    path = os.path.join(here, 'autotest.sh')
    if os.path.isfile(path):
        return path
    return filedialog.askopenfilename(title='Select autotest.sh', filetypes=[('Shell script', '*.sh'), ('All files', '*')])


class AutotestGUI(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title('AutoTest Linux Framework - GUI')
        self.geometry('1100x720')
        self.minsize(900, 600)

        self.autotest_path = find_autotest_script()
        if not self.autotest_path:
            messagebox.showerror('Error', 'autotest.sh not found')
            self.destroy()
            return

        self.env_path = tk.StringVar(value='')
        self.ip_host = tk.StringVar(value=os.environ.get('AUTOTEST_IPERF_BIND', '192.168.10.18'))
        self.monitor_interval = tk.StringVar(value='10')
        self.duration_secs = tk.StringVar(value='600')
        self.mem_mb = tk.StringVar(value='4096')
        self.mem_loops = tk.StringVar(value='1')
        self.disk_dir = tk.StringVar(value=os.path.expanduser('~'))
        self.preset = tk.StringVar(value='4h')

        self.lang = tk.StringVar(value='ru')
        self._build_ui()
        self._build_i18n()
        self._apply_language()

    def _build_ui(self):
        top = ttk.Frame(self)
        top.pack(fill=tk.X, padx=8, pady=6)

        self.lbl_autotest = ttk.Label(top, text='autotest.sh:')
        self.lbl_autotest.pack(side=tk.LEFT)
        self.autotest_label = ttk.Label(top, text=self.autotest_path)
        self.autotest_label.pack(side=tk.LEFT, padx=6)
        self.btn_change_autotest = ttk.Button(top, text='Change...', command=self._change_autotest)
        self.btn_change_autotest.pack(side=tk.LEFT, padx=6)
        self.lbl_env = ttk.Label(top, text='.env:')
        self.lbl_env.pack(side=tk.LEFT, padx=(16, 4))
        ttk.Entry(top, textvariable=self.env_path, width=40).pack(side=tk.LEFT)
        self.btn_browse_env = ttk.Button(top, text='Browse', command=self._browse_env)
        self.btn_browse_env.pack(side=tk.LEFT, padx=4)
        self.btn_config_show = ttk.Button(top, text='Config Show', command=lambda: self.run_cmd(['config-show']))
        self.btn_config_show.pack(side=tk.LEFT, padx=8)
        self.lbl_lang = ttk.Label(top, text='Language:')
        self.lbl_lang.pack(side=tk.LEFT, padx=(12,4))
        self.lang_btn = ttk.Button(top, text='RU', width=4, command=self._toggle_lang)
        self.lang_btn.pack(side=tk.LEFT)

        self.nb = ttk.Notebook(self)
        self.nb.pack(fill=tk.BOTH, expand=True, padx=8, pady=6)

        self.tab_common = self._tab_common()
        self.tab_tests = self._tab_tests()
        self.tab_network = self._tab_network()
        self.tab_tasks = self._tab_tasks()
        self.tab_scheduling = self._tab_scheduling()
        self.tab_reports = self._tab_reports()

        self.nb.add(self.tab_common, text='Common')
        self.nb.add(self.tab_tests, text='Tests')
        self.nb.add(self.tab_network, text='Network')
        self.nb.add(self.tab_tasks, text='Tasks')
        self.nb.add(self.tab_scheduling, text='Scheduling')
        self.nb.add(self.tab_reports, text='Reports')

        # Output
        out_frame = ttk.LabelFrame(self, text='Output')
        out_frame.pack(fill=tk.BOTH, expand=True, padx=8, pady=(0, 8))
        self.output = scrolledtext.ScrolledText(out_frame, height=12, wrap=tk.WORD)
        self.output.pack(fill=tk.BOTH, expand=True)

        # Footer
        footer = ttk.Frame(self)
        footer.pack(fill=tk.X, padx=8, pady=(0, 8))
        self.status_var = tk.StringVar(value='IDLE')
        ttk.Label(footer, text='Status:').pack(side=tk.LEFT)
        self.lbl_status = ttk.Label(footer, textvariable=self.status_var, foreground='#2e86de')
        self.lbl_status.pack(side=tk.LEFT, padx=(4, 12))
        self.btn_stop = ttk.Button(footer, text='Stop', command=self._stop_proc)
        self.btn_stop.pack(side=tk.LEFT, padx=(0, 12))
        self.btn_stop.state(['disabled'])

        self.btn_doctor = ttk.Button(footer, text='Doctor', command=lambda: self.run_cmd(['doctor']))
        self.btn_doctor.pack(side=tk.LEFT)
        self.btn_deps = ttk.Button(footer, text='Deps All', command=lambda: self.run_cmd(['deps-all']))
        self.btn_deps.pack(side=tk.LEFT, padx=6)
        self.btn_help = ttk.Button(footer, text='Help', command=self._run_help)
        self.btn_help.pack(side=tk.LEFT, padx=6)

    def _tab_common(self):
        f = ttk.Frame()
        self.btn_install = ttk.Button(f, text='Install', command=lambda: self.run_cmd(['install']))
        self.btn_install.grid(row=0, column=0, padx=6, pady=6, sticky='w')
        self.btn_monitor_once = ttk.Button(f, text='Monitor Once', command=lambda: self.run_cmd(['monitor-once']))
        self.btn_monitor_once.grid(row=0, column=1, padx=6, pady=6, sticky='w')
        self.lbl_loop = ttk.Label(f, text='Loop (sec):')
        self.lbl_loop.grid(row=1, column=0, sticky='e', padx=6)
        ttk.Entry(f, textvariable=self.monitor_interval, width=8).grid(row=1, column=1, sticky='w')
        self.btn_monitor_loop = ttk.Button(f, text='Monitor Loop', command=lambda: self.run_cmd(['monitor-loop', self.monitor_interval.get()]))
        self.btn_monitor_loop.grid(row=1, column=2, padx=6)
        self.btn_htop = ttk.Button(f, text='HTOP Snapshot', command=lambda: self.run_cmd(['htop-snapshot']))
        self.btn_htop.grid(row=2, column=0, padx=6, pady=6)
        return f

    def _tab_tests(self):
        f = ttk.Frame()
        self.lbl_duration = ttk.Label(f, text='Duration (sec):')
        self.lbl_duration.grid(row=0, column=0, sticky='e', padx=6, pady=6)
        ttk.Entry(f, textvariable=self.duration_secs, width=10).grid(row=0, column=1, sticky='w')
        self.btn_cpu = ttk.Button(f, text='CPU Stress', command=lambda: self.run_cmd(['cpu-stress', self.duration_secs.get()]))
        self.btn_cpu.grid(row=0, column=2, padx=6)
        self.btn_gpu = ttk.Button(f, text='GPU Burn', command=lambda: self.run_cmd(['gpuburn', self.duration_secs.get()]))
        self.btn_gpu.grid(row=0, column=3, padx=6)

        self.lbl_ram_mb = ttk.Label(f, text='RAM MB:')
        self.lbl_ram_mb.grid(row=1, column=0, sticky='e', padx=6)
        ttk.Entry(f, textvariable=self.mem_mb, width=10).grid(row=1, column=1, sticky='w')
        self.lbl_loops = ttk.Label(f, text='Loops:')
        self.lbl_loops.grid(row=1, column=2, sticky='e')
        ttk.Entry(f, textvariable=self.mem_loops, width=8).grid(row=1, column=3, sticky='w')
        self.btn_memtest = ttk.Button(f, text='RAM Memtest', command=lambda: self.run_cmd(['ram-memtest', self.mem_mb.get(), self.mem_loops.get()]))
        self.btn_memtest.grid(row=1, column=4, padx=6)

        self.lbl_fio_dir = ttk.Label(f, text='FIO dir:')
        self.lbl_fio_dir.grid(row=2, column=0, sticky='e', padx=6)
        ttk.Entry(f, textvariable=self.disk_dir, width=40).grid(row=2, column=1, columnspan=3, sticky='we')
        self.btn_browse_dir = ttk.Button(f, text='Browse', command=self._browse_dir)
        self.btn_browse_dir.grid(row=2, column=4, padx=6)
        self.btn_fio = ttk.Button(f, text='Disk FIO', command=lambda: self.run_cmd(['disk-fio', self.disk_dir.get(), self.duration_secs.get()]))
        self.btn_fio.grid(row=2, column=5, padx=6)
        f.columnconfigure(1, weight=1)
        f.columnconfigure(2, weight=0)
        return f

    def _tab_network(self):
        f = ttk.Frame()
        self.lbl_server = ttk.Label(f, text='Server host:')
        self.lbl_server.grid(row=0, column=0, sticky='e', padx=6, pady=6)
        ttk.Entry(f, textvariable=self.ip_host, width=24).grid(row=0, column=1, sticky='w')
        self.btn_iperf_srv = ttk.Button(f, text='Start iperf3 Server', command=lambda: self.run_cmd(['net-iperf3-server']))
        self.btn_iperf_srv.grid(row=0, column=2, padx=6)
        self.btn_iperf_cli = ttk.Button(f, text='Run iperf3 Client (10x10s avg)', command=lambda: self.run_cmd(['net-iperf3-client', self.ip_host.get(), '10', '10']))
        self.btn_iperf_cli.grid(row=0, column=3, padx=6)
        return f

    def _tab_tasks(self):
        f = ttk.Frame()
        self.lbl_preset = ttk.Label(f, text='Preset:')
        self.lbl_preset.grid(row=0, column=0, sticky='e', padx=6, pady=6)
        presets = ['4h', '8h', '24h', '48h', 'gpu_only', 'cpu_only']
        ttk.Combobox(f, textvariable=self.preset, values=presets, state='readonly', width=12).grid(row=0, column=1, sticky='w')
        self.btn_run_task = ttk.Button(f, text='Run Task', command=lambda: self.run_cmd(['task', 'run', self.preset.get()]))
        self.btn_run_task.grid(row=0, column=2, padx=6)
        return f

    def _tab_scheduling(self):
        f = ttk.Frame()
        self.btn_setup_cron = ttk.Button(f, text='Setup Cron', command=lambda: self.run_cmd(['setup-cron']))
        self.btn_setup_cron.grid(row=0, column=0, padx=6, pady=6)
        self.btn_setup_systemd = ttk.Button(f, text='Setup systemd', command=lambda: self.run_cmd(['setup-systemd']))
        self.btn_setup_systemd.grid(row=0, column=1, padx=6)
        self.btn_remove_systemd = ttk.Button(f, text='Remove systemd', command=lambda: self.run_cmd(['remove-systemd']))
        self.btn_remove_systemd.grid(row=0, column=2, padx=6)
        return f

    def _tab_reports(self):
        f = ttk.Frame()
        self.btn_report = ttk.Button(f, text='Report (HTML)', command=lambda: self.run_cmd(['report']))
        self.btn_report.grid(row=0, column=0, padx=6, pady=6)
        self.btn_collect = ttk.Button(f, text='Collect Logs', command=lambda: self.run_cmd(['collect']))
        self.btn_collect.grid(row=0, column=1, padx=6)
        self.btn_rotate = ttk.Button(f, text='Rotate Logs', command=lambda: self.run_cmd(['rotate']))
        self.btn_rotate.grid(row=0, column=2, padx=6)
        self.btn_clean = ttk.Button(f, text='Clean Logs (ALL)', command=lambda: self.run_cmd(['clean', '--all']))
        self.btn_clean.grid(row=0, column=3, padx=6)
        ttk.Button(f, text='Open Last Report', command=self._open_last_report).grid(row=0, column=4, padx=6)
        return f

    def _browse_env(self):
        path = filedialog.askopenfilename(title='Select .env', filetypes=[('Env', '*.env'), ('All files', '*')])
        if path:
            self.env_path.set(path)

    def _browse_dir(self):
        path = filedialog.askdirectory(title='Select directory')
        if path:
            self.disk_dir.set(path)

    def _change_autotest(self):
        path = filedialog.askopenfilename(title='Select autotest.sh', filetypes=[('Shell script', '*.sh'), ('All files', '*')])
        if path:
            self.autotest_path = path
            self.autotest_label.config(text=path)

    def _toggle_lang(self):
        # Toggle between 'ru' and 'en'
        cur = self.lang.get()
        new = 'en' if cur == 'ru' else 'ru'
        self.lang.set(new)
        self.lang_btn.config(text=new.upper())
        self._apply_language()

    def _run_help(self):
        if self.lang.get() == 'ru':
            self.run_cmd(['help-ru'])
        else:
            self.run_cmd(['help-en'])

    def _build_i18n(self):
        self.i18n = {
            'tabs': {
                'ru': ['Общее', 'Тесты', 'Сеть', 'Задачи', 'Планировщик', 'Отчёты'],
                'en': ['Common', 'Tests', 'Network', 'Tasks', 'Scheduling', 'Reports'],
            },
            'labels': {
                'ru': {
                    'autotest': 'autotest.sh:', 'change': 'Выбрать...', 'env': '.env:', 'browse': 'Обзор',
                    'config_show': 'Показать конфиг', 'language': 'Язык:', 'loop': 'Период (сек):',
                    'duration': 'Длительность (сек):', 'ram_mb': 'ОЗУ (МБ):', 'loops': 'Повторы:', 'fio_dir': 'Папка FIO:',
                    'server_host': 'Сервер:', 'preset': 'Пресет:',
                },
                'en': {
                    'autotest': 'autotest.sh:', 'change': 'Change...', 'env': '.env:', 'browse': 'Browse',
                    'config_show': 'Config Show', 'language': 'Language:', 'loop': 'Loop (sec):',
                    'duration': 'Duration (sec):', 'ram_mb': 'RAM MB:', 'loops': 'Loops:', 'fio_dir': 'FIO dir:',
                    'server_host': 'Server host:', 'preset': 'Preset:',
                }
            },
            'buttons': {
                'ru': {
                    'install': 'Установка', 'monitor_once': 'Разовый мониторинг', 'monitor_loop': 'Циклический мониторинг',
                    'htop': 'HTOP снимок', 'cpu': 'CPU стресс', 'gpu': 'GPU тест', 'memtest': 'RAM тест', 'browse': 'Обзор',
                    'fio': 'Диск (FIO)', 'iperf_srv': 'Сервер iperf3', 'iperf_cli': 'Клиент iperf3 (10×10с)',
                    'run_task': 'Запустить задачу', 'setup_cron': 'Настроить Cron', 'setup_systemd': 'Настроить systemd',
                    'remove_systemd': 'Удалить systemd', 'report': 'Отчёт (HTML)', 'collect': 'Собрать логи', 'rotate': 'Сжать логи',
                    'clean': 'Очистить логи (ВСЕ)', 'doctor': 'Проверка', 'deps': 'Зависимости', 'help': 'Справка'
                },
                'en': {
                    'install': 'Install', 'monitor_once': 'Monitor Once', 'monitor_loop': 'Monitor Loop',
                    'htop': 'HTOP Snapshot', 'cpu': 'CPU Stress', 'gpu': 'GPU Burn', 'memtest': 'RAM Memtest', 'browse': 'Browse',
                    'fio': 'Disk FIO', 'iperf_srv': 'Start iperf3 Server', 'iperf_cli': 'Run iperf3 Client (10x10s avg)',
                    'run_task': 'Run Task', 'setup_cron': 'Setup Cron', 'setup_systemd': 'Setup systemd',
                    'remove_systemd': 'Remove systemd', 'report': 'Report (HTML)', 'collect': 'Collect Logs', 'rotate': 'Rotate Logs',
                    'clean': 'Clean Logs (ALL)', 'doctor': 'Doctor', 'deps': 'Deps All', 'help': 'Help'
                }
            }
        }

    def _apply_language(self):
        lang = self.lang.get()
        # Tabs
        titles = self.i18n['tabs'][lang]
        self.nb.tab(self.tab_common, text=titles[0])
        self.nb.tab(self.tab_tests, text=titles[1])
        self.nb.tab(self.tab_network, text=titles[2])
        self.nb.tab(self.tab_tasks, text=titles[3])
        self.nb.tab(self.tab_scheduling, text=titles[4])
        self.nb.tab(self.tab_reports, text=titles[5])
        # Labels
        L = self.i18n['labels'][lang]
        self.lbl_autotest.config(text=L['autotest'])
        self.btn_change_autotest.config(text=self.i18n['labels'][lang]['change'])
        self.lbl_env.config(text=L['env'])
        self.btn_browse_env.config(text=L['browse'])
        self.btn_config_show.config(text=L['config_show'])
        self.lbl_lang.config(text=L['language'])
        self.lbl_loop.config(text=L['loop'])
        self.lbl_duration.config(text=L['duration'])
        self.lbl_ram_mb.config(text=L['ram_mb'])
        self.lbl_loops.config(text=L['loops'])
        self.lbl_fio_dir.config(text=L['fio_dir'])
        self.lbl_server.config(text=L['server_host'])
        self.lbl_preset.config(text=L['preset'])
        # Buttons
        B = self.i18n['buttons'][lang]
        self.btn_install.config(text=B['install'])
        self.btn_monitor_once.config(text=B['monitor_once'])
        self.btn_monitor_loop.config(text=B['monitor_loop'])
        self.btn_htop.config(text=B['htop'])
        self.btn_cpu.config(text=B['cpu'])
        self.btn_gpu.config(text=B['gpu'])
        self.btn_memtest.config(text=B['memtest'])
        self.btn_browse_dir.config(text=B['browse'])
        self.btn_fio.config(text=B['fio'])
        self.btn_iperf_srv.config(text=B['iperf_srv'])
        self.btn_iperf_cli.config(text=B['iperf_cli'])
        self.btn_run_task.config(text=B['run_task'])
        self.btn_setup_cron.config(text=B['setup_cron'])
        self.btn_setup_systemd.config(text=B['setup_systemd'])
        self.btn_remove_systemd.config(text=B['remove_systemd'])
        self.btn_report.config(text=B['report'])
        self.btn_collect.config(text=B['collect'])
        self.btn_rotate.config(text=B['rotate'])
        self.btn_clean.config(text=B['clean'])
        self.btn_doctor.config(text=B['doctor'])
        self.btn_deps.config(text=B['deps'])
        self.btn_help.config(text=B['help'])

    def run_cmd(self, args):
        if getattr(self, 'current_proc', None) is not None:
            messagebox.showwarning('Busy', 'Another command is running. Stop it first.')
            return
        cmd = [self.autotest_path]
        if self.env_path.get():
            cmd += ['--config', self.env_path.get()]
        cmd += args
        self._append(f'$ {" ".join(cmd)}\n')

        def worker():
            try:
                self.status_var.set(f'RUNNING: {" ".join(args)}')
                self.btn_stop.state(['!disabled'])
                proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                self.current_proc = proc
                for line in proc.stdout:
                    self._append(line)
                proc.wait()
                self._append(f"\n[exit {proc.returncode}]\n")
            except Exception as e:
                self._append(f"\n[error] {e}\n")
            finally:
                self.current_proc = None
                self.status_var.set('IDLE')
                self.btn_stop.state(['disabled'])

        threading.Thread(target=worker, daemon=True).start()

    def _append(self, text: str):
        self.output.insert(tk.END, text)
        self.output.see(tk.END)

    def _stop_proc(self):
        proc = getattr(self, 'current_proc', None)
        if not proc:
            return
        try:
            self._append('\n[stopping]\n')
            proc.terminate()
            # wait a bit then kill if needed
            for _ in range(10):
                ret = proc.poll()
                if ret is not None:
                    break
                time.sleep(0.2)
            if proc.poll() is None:
                proc.kill()
        except Exception as e:
            self._append(f'\n[stop error] {e}\n')

    def _get_archive_dir(self) -> str:
        # Try to read from .env; else default
        default = os.path.expanduser('~/AutoTest_Archives')
        envp = self.env_path.get()
        if envp and os.path.isfile(envp):
            try:
                with open(envp, 'r', encoding='utf-8') as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith('AUTOTEST_ARCHIVE_DIR'):
                            val = line.split('=', 1)[1].strip().strip('"')
                            return os.path.expanduser(val)
            except Exception:
                pass
        return default

    def _open_last_report(self):
        import glob, webbrowser
        arch = self._get_archive_dir()
        pattern = os.path.join(arch, 'report_*.html')
        files = sorted(glob.glob(pattern), key=os.path.getmtime, reverse=True)
        if not files:
            messagebox.showinfo('Report', 'No report files found')
            return
        webbrowser.open(f'file://{files[0]}')


if __name__ == '__main__':
    app = AutotestGUI()
    app.mainloop()


