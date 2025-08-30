use iced::widget::{
    button, check_box, column, container, pick_list, progress_bar, row, rule, scrollable, text,
    text_input, toggler,
};
use iced::{executor, window, Alignment, Application, Command, Element, Event, Length, Settings, Subscription, Theme};
use rfd::FileDialog;
use std::path::{Path, PathBuf};
use std::str::FromStr;

mod subscription;

// --- Main ---
pub fn main() -> iced::Result {
    CykoApp::run(Settings {
        window: iced::window::Settings { size: (800, 650), ..Default::default() },
        ..Default::default()
    })
}

// --- State & Data Structures ---
struct CykoApp {
    handbrake_version: String,
    available_encoders: Vec<Encoder>,
    active_tab: Tab,
    status_text: String,
    input_files: Vec<InputFile>,
    output_dir: String,
    command_queue: Vec<String>,
    encoder: Encoder,
    mode: Mode,
    video_value: String,
    audio_value: String,
    preset: String,
    tune: String,
    encopts: String,
    encoder_profile: String,
    encoder_level: String,
    multi_pass: bool,
    turbo: bool,
    framerate: String,
    framerate_mode: FramerateMode,
    resolution_value: String,
    is_width_resolution: bool,
    hard_subs: bool,
    shutdown_after_done: bool,
    show_console: bool,
    hw_decoding: bool,
    is_encoding: bool,
    encode_progress: f32,
    abort_sender: Option<tokio::sync::broadcast::Sender<()>>,
    estimated_size_mb: f64,
}

#[derive(Debug, Clone)]
struct InputFile { path: PathBuf, duration: Option<f64>, status: ScanStatus }
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ScanStatus { Pending, Scanning, Completed, Failed }

// --- Messages & Enums ---
#[derive(Debug, Clone)]
pub enum Progress { Started(String), Updated(f32), Finished, AllFinished, Error(String) }
#[derive(Debug, Clone)]
enum Message { StartupInfoLoaded(Result<(String, Vec<Encoder>), String>), MetadataScanned(Vec<(PathBuf, Result<f64, String>)>), TabSelected(Tab), EventOccurred(Event), FilesAdded(Option<Vec<PathBuf>>), OutputDirectorySelected(Option<PathBuf>>), AddFiles, SelectOutputDirectory, ClearInputFiles, EncoderChanged(Encoder), ModeChanged(Mode), PresetChanged(String), TuneChanged(String), VideoValueChanged(String), AudioValueChanged(String), ResolutionChanged(String), ResolutionToggleChanged(bool), HardSubsChanged(bool), ShutdownChanged(bool), ShowConsoleChanged(bool), EncoptsChanged(String), EncoderProfileChanged(String), EncoderLevelChanged(String), MultiPassChanged(bool), TurboChanged(bool), FramerateChanged(String), FramerateModeChanged(FramerateMode), HwDecodingChanged(bool), Enqueue, Encode, Abort, ClearCommandQueue, EncodingProgress(Progress) }
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
enum Tab { #[default] Input, Output, Options, About }
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, PartialOrd, Ord)]
enum Encoder { SvtAv1, SvtAv1_10bit, Ffv1, #[default] X264, X264_10bit, VceH264, X265, X265_10bit, X265_12bit, VceH265, VceH265_10bit, Mpeg4, Mpeg2, Vp8, Vp9, Vp9_10bit, Theora }
impl FromStr for Encoder { type Err = (); fn from_str(s: &str) -> Result<Self, Self::Err> { match s { "svt_av1"=>Ok(Encoder::SvtAv1), "svt_av1_10bit"=>Ok(Encoder::SvtAv1_10bit), "ffv1"=>Ok(Encoder::Ffv1), "x264"=>Ok(Encoder::X264), "x264_10bit"=>Ok(Encoder::X264_10bit), "vce_h264"=>Ok(Encoder::VceH264), "x265"=>Ok(Encoder::X265), "x265_10bit"=>Ok(Encoder::X265_10bit), "x265_12bit"=>Ok(Encoder::X265_12bit), "vce_h265"=>Ok(Encoder::VceH265), "vce_h265_10bit"=>Ok(Encoder::VceH265_10bit), "mpeg4"=>Ok(Encoder::Mpeg4), "mpeg2"=>Ok(Encoder::Mpeg2), "VP8"=>Ok(Encoder::Vp8), "VP9"=>Ok(Encoder::Vp9), "VP9_10bit"=>Ok(Encoder::Vp9_10bit), "theora"=>Ok(Encoder::Theora), _=>Err(()), } } }
impl std::fmt::Display for Encoder { fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result { write!(f, "{:?}", self) } }
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
enum Mode { #[default] TargetQuality, TargetBitrate }
const MODES: &[Mode] = &[Mode::TargetQuality, Mode::TargetBitrate];
impl std::fmt::Display for Mode { fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result { write!(f, "{}", match self { Mode::TargetQuality => "Target Quality", Mode::TargetBitrate => "Target Bitrate" }) } }
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
enum FramerateMode { Vfr, #[default] Cfr, Pfr }
const FRAMERATE_MODES: &[FramerateMode] = &[FramerateMode::Vfr, FramerateMode::Cfr, FramerateMode::Pfr];
impl std::fmt::Display for FramerateMode { fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result { write!(f, "{}", match self { FramerateMode::Vfr => "VFR", FramerateMode::Cfr => "CFR", FramerateMode::Pfr => "PFR" }) } }

// --- Application Impl ---
impl Application for CykoApp {
    type Executor = executor::Default;
    type Message = Message;
    type Theme = Theme;
    type Flags = ();

    fn new(_flags: ()) -> (Self, Command<Message>) { (Self { handbrake_version: "Loading...".to_string(), available_encoders: Vec::new(), active_tab: Tab::default(), status_text: "Loading HandBrakeCLI info...".to_string(), input_files: Vec::new(), output_dir: std::env::current_dir().unwrap_or_default().to_string_lossy().to_string(), command_queue: Vec::new(), encoder: Encoder::default(), mode: Mode::default(), video_value: "23".to_string(), audio_value: "64".to_string(), preset: "medium".to_string(), tune: "animation".to_string(), encopts: "".to_string(), encoder_profile: "".to_string(), encoder_level: "".to_string(), multi_pass: false, turbo: false, framerate: "30".to_string(), framerate_mode: FramerateMode::default(), resolution_value: "720".to_string(), is_width_resolution: false, hard_subs: false, shutdown_after_done: false, show_console: false, hw_decoding: false, is_encoding: false, encode_progress: 0.0, abort_sender: None, estimated_size_mb: 0.0, }, Command::perform(load_startup_info(), Message::StartupInfoLoaded)) }
    fn title(&self) -> String { String::from("Cyko - Rust Edition") }

    fn subscription(&self) -> Subscription<Message> {
        let events = iced::subscription::events().map(Message::EventOccurred);
        if self.is_encoding {
            let encoding_sub = subscription::encode(self.command_queue.clone(), self.abort_sender.as_ref().unwrap().subscribe()).map(Message::EncodingProgress);
            Subscription::batch(vec![events, encoding_sub])
        } else { events }
    }

    fn update(&mut self, message: Message) -> Command<Message> {
        if !self.is_encoding {
            match message {
                Message::TabSelected(tab) => self.active_tab = tab,
                Message::AddFiles => return Command::perform(async { FileDialog::new().add_filter("Video", &["mkv", "mp4", "m4v", "avi", "ogm"]).pick_files() }, Message::FilesAdded),
                Message::FilesAdded(Some(files)) => {
                    let new_files: Vec<_> = files.into_iter().map(|path| InputFile { path, duration: None, status: ScanStatus::Pending }).collect();
                    let paths_to_scan: Vec<_> = new_files.iter().map(|f| f.path.clone()).collect();
                    if !paths_to_scan.is_empty() {
                        self.input_files.extend(new_files);
                        self.status_text = format!("Scanning metadata for {} files...", paths_to_scan.len());
                        return Command::perform(subscription::scan_metadata(paths_to_scan), Message::MetadataScanned);
                    }
                }
                Message::SelectOutputDirectory => return Command::perform(async { FileDialog::new().pick_folder() }, Message::OutputDirectorySelected),
                Message::OutputDirectorySelected(Some(folder)) => self.output_dir = folder.to_string_lossy().to_string(),
                Message::ClearInputFiles => { self.input_files.clear(); self.calculate_and_update_estimated_size(); }
                Message::EncoderChanged(encoder) => self.encoder = encoder,
                Message::ModeChanged(mode) => { self.mode = mode; self.calculate_and_update_estimated_size(); }
                Message::VideoValueChanged(v) => { self.video_value = v; self.calculate_and_update_estimated_size(); }
                Message::AudioValueChanged(v) => { self.audio_value = v; self.calculate_and_update_estimated_size(); }
                Message::PresetChanged(p) => self.preset = p,
                Message::TuneChanged(t) => self.tune = t,
                Message::EncoptsChanged(v) => self.encopts = v,
                Message::EncoderProfileChanged(v) => self.encoder_profile = v,
                Message::EncoderLevelChanged(v) => self.encoder_level = v,
                Message::MultiPassChanged(v) => self.multi_pass = v,
                Message::TurboChanged(v) => self.turbo = v,
                Message::FramerateChanged(v) => self.framerate = v,
                Message::FramerateModeChanged(v) => self.framerate_mode = v,
                Message::HwDecodingChanged(v) => self.hw_decoding = v,
                Message::ResolutionChanged(v) => self.resolution_value = v,
                Message::ResolutionToggleChanged(is_width) => self.is_width_resolution = is_width,
                Message::HardSubsChanged(v) => self.hard_subs = v,
                Message::ShutdownChanged(v) => self.shutdown_after_done = v,
                Message::ShowConsoleChanged(v) => self.show_console = v,
                Message::ClearCommandQueue => self.command_queue.clear(),
                _ => {}
            }
        }

        match message {
            Message::StartupInfoLoaded(Ok((version, encoders))) => { self.handbrake_version = version; self.available_encoders = encoders; if !self.available_encoders.contains(&self.encoder) { self.encoder = *self.available_encoders.get(0).unwrap_or(&Encoder::default()); } self.status_text = "Ready".to_string(); }
            Message::StartupInfoLoaded(Err(e)) => { self.status_text = format!("Error: {}", e); }
            Message::MetadataScanned(results) => { for (path, result) in results { if let Some(file) = self.input_files.iter_mut().find(|f| f.path == path) { match result { Ok(duration) => { file.duration = Some(duration); file.status = ScanStatus::Completed; } Err(_) => file.status = ScanStatus::Failed, } } } self.calculate_and_update_estimated_size(); self.status_text = "Ready".to_string(); }
            Message::EventOccurred(Event::Window(window::Event::FileDropped(path))) => { if !self.is_encoding && self.active_tab == Tab::Input { return Command::perform(async { vec![path] }, |files| Message::FilesAdded(Some(files))); } }
            Message::Enqueue => {
                if self.is_encoding || self.input_files.is_empty() { return Command::none(); }
                let mut base_opts = format!("-e {}", self.encoder);
                match self.mode { Mode::TargetQuality => base_opts.push_str(&format!(" -q {}", self.video_value)), Mode::TargetBitrate => base_opts.push_str(&format!(" -b {}", self.video_value)), }
                if !self.preset.is_empty() { base_opts.push_str(&format!(" --encoder-preset {}", self.preset)); }
                if !self.tune.is_empty() { base_opts.push_str(&format!(" --encoder-tune {}", self.tune)); }
                if !self.encoder_profile.is_empty() { base_opts.push_str(&format!(" --encoder-profile {}", self.encoder_profile)); }
                if !self.encoder_level.is_empty() { base_opts.push_str(&format!(" --encoder-level {}", self.encoder_level)); }
                if !self.encopts.is_empty() { base_opts.push_str(&format!(" -x {}", self.encopts)); }
                if self.multi_pass { base_opts.push_str(" --multi-pass"); }
                if self.turbo { base_opts.push_str(" -T"); }
                if self.hw_decoding { base_opts.push_str(" --enable-hw-decoding nvdec"); }
                if !self.framerate.is_empty() { base_opts.push_str(&format!(" -r {}", self.framerate)); }
                match self.framerate_mode { FramerateMode::Vfr => base_opts.push_str(" --vfr"), FramerateMode::Cfr => base_opts.push_str(" --cfr"), FramerateMode::Pfr => base_opts.push_str(" --pfr"), }
                let resolution_string = if self.is_width_resolution { format!("-X {}", self.resolution_value) } else { format!("-Y {}", self.resolution_value) };
                for file in &self.input_files { let input_path = format!("\"{}\"", file.path.to_string_lossy()); let file_stem = file.path.file_stem().unwrap_or_default().to_string_lossy(); let (output_ext, container_format, subtitle_opts) = if self.hard_subs { ("-OUT.mp4", "-f mp4", "-s 1 --subtitle-burned") } else { ("-OUT.mkv", "-f mkv", "--subtitle-lang-list all --all-subtitles --subtitle-default") }; let output_filename = format!("{}{}", file_stem, output_ext); let output_path = format!("\"{}\"", Path::new(&self.output_dir).join(output_filename).to_string_lossy()); let command = format!("-i {} {} {} {} -m -E opus --mixdown stereo -B {} {} --non-anamorphic --keep-display-aspect {} --all-audio", input_path, container_format, output_path, base_opts, self.audio_value, resolution_string, subtitle_opts); self.command_queue.push(command.replace("  ", " ").trim().to_string()); }
                self.status_text = format!("{} files enqueued.", self.input_files.len()); self.input_files.clear(); self.active_tab = Tab::Output;
            }
            Message::Encode => { if !self.command_queue.is_empty() && !self.is_encoding { self.is_encoding = true; let (tx, _) = tokio::sync::broadcast::channel(1); self.abort_sender = Some(tx); self.encode_progress = 0.0; } }
            Message::Abort => { if let Some(sender) = &self.abort_sender { let _ = sender.send(()); } }
            Message::EncodingProgress(progress) => match progress {
                Progress::Started(cmd) => { self.status_text = format!("Encoding: {}...", cmd.chars().take(60).collect::<String>()); self.encode_progress = 0.0; },
                Progress::Updated(percent) => self.encode_progress = percent,
                Progress::Finished => {},
                Progress::AllFinished => { self.status_text = "All encoding tasks finished.".to_string(); self.is_encoding = false; self.encode_progress = 100.0; self.command_queue.clear(); self.abort_sender = None; if self.shutdown_after_done { return Command::perform(shutdown_system(), |_| Message::EventOccurred(Event::Closed)); } },
                Progress::Error(e) => { self.status_text = format!("Error: {}", e); self.is_encoding = false; self.abort_sender = None; }
            },
            _ => {}
        }
        Command::none()
    }

    fn view(&self) -> Element<Message> {
        let header = row![ button(text("Input")).on_press(Message::TabSelected(Tab::Input)), button(text("Output")).on_press(Message::TabSelected(Tab::Output)), button(text("Options")).on_press(Message::TabSelected(Tab::Options)), button(text("About")).on_press(Message::TabSelected(Tab::About)), ].spacing(10);
        let content = match self.active_tab { Tab::Input => view_input_tab(self), Tab::Output => view_output_tab(self), Tab::Options => view_options_tab(self), Tab::About => view_about_tab(self), };
        let status_bar = row![progress_bar(0.0..=100.0, self.encode_progress), text(&self.status_text).size(16)].spacing(10).align_items(Alignment::Center);
        let main_view = column![header, content, status_bar].padding(20).spacing(20);
        container(main_view).width(Length::Fill).height(Length::Fill).into()
    }
}

impl CykoApp { fn calculate_and_update_estimated_size(&mut self) { if self.mode == Mode::TargetQuality { self.estimated_size_mb = 0.0; return; } let video_kbps = self.video_value.parse::<f64>().unwrap_or(0.0); let audio_kbps = self.audio_value.parse::<f64>().unwrap_or(0.0); if video_kbps <= 0.0 || audio_kbps <= 0.0 { self.estimated_size_mb = 0.0; return; } let total_kbps = video_kbps + audio_kbps; let total_duration_secs: f64 = self.input_files.iter().filter_map(|f| f.duration).sum(); if total_duration_secs > 0.0 { let total_kbits = total_kbps * total_duration_secs; let total_mbytes = total_kbits / 8.0 / 1024.0; self.estimated_size_mb = total_mbytes; } else { self.estimated_size_mb = 0.0; } } }
async fn load_startup_info() -> Result<(String, Vec<Encoder>), String> { let version_output = tokio::process::Command::new("HandBrakeCLI").arg("--version").output().await; let version = match version_output { Ok(output) => String::from_utf8(output.stdout).unwrap_or_else(|_| "Failed to read version".to_string()), Err(e) => return Err(format!("HandBrakeCLI not found or failed to run: {}", e)), }; let help_output = tokio::process::Command::new("HandBrakeCLI").arg("-h").output().await; let help_text = match help_output { Ok(output) => String::from_utf8(output.stdout).unwrap_or_else(|_| "".to_string()), Err(_) => return Err("Failed to get encoder list from HandBrakeCLI -h".to_string()), }; let mut encoders = Vec::new(); let mut in_encoder_section = false; for line in help_text.lines() { if line.contains("-e, --encoder <string>") { in_encoder_section = true; continue; } if in_encoder_section { let trimmed = line.trim(); if trimmed.is_empty() || !line.starts_with(" ") { break; } if let Ok(encoder) = Encoder::from_str(trimmed) { encoders.push(encoder); } } } encoders.sort(); encoders.dedup(); Ok((version.lines().next().unwrap_or("Unknown Version").to_string(), encoders)) }
async fn shutdown_system() { #[cfg(target_os = "windows")] { std::process::Command::new("shutdown").args(["/s", "/t", "1"]).spawn().ok(); } #[cfg(not(target_os = "windows"))] { std::process::Command::new("shutdown").arg("-h").arg("now").spawn().ok(); } }

// --- View Functions ---
fn view_input_tab(app: &CykoApp) -> Element<Message> { let file_list_items: Vec<Element<Message>> = app.input_files.iter().map(|file| { let status_text = match file.status { ScanStatus::Pending => " [Pending Scan]", ScanStatus::Scanning => " [Scanning...]", ScanStatus::Completed => "", ScanStatus::Failed => " [Scan Failed]", }; text(format!("{}{}", file.path.to_string_lossy(), status_text)).into() }).collect(); let file_list = if file_list_items.is_empty() { container(text("Drag and drop files here or click 'Add Files'")).width(Length::Fill).height(Length::Fill).center_x().center_y() } else { container(scrollable(column(file_list_items).spacing(5))) }; let controls = row![ button("Add Files").on_press_maybe(if app.is_encoding { None } else { Some(Message::AddFiles) }), button("Clear").on_press_maybe(if app.is_encoding { None } else { Some(Message::ClearInputFiles) }), ].spacing(10); let size_preview = if app.mode == Mode::TargetBitrate { format!("Estimated Total Size: {:.2} MB", app.estimated_size_mb) } else { "Estimated Total Size: N/A (Quality Mode)".to_string() }; column![controls, file_list.height(Length::Fill), text(size_preview)].spacing(20).into() }
fn view_output_tab(app: &CykoApp) -> Element<Message> { let queue_list = if app.command_queue.is_empty() { container(text("Queue is empty.")).width(Length::Fill).height(Length::Fill).center_x().center_y() } else { let items: Vec<Element<Message>> = app.command_queue.iter().map(|cmd| text(cmd).into()).collect(); container(scrollable(column(items).spacing(5))) }; let controls = row![ button("Encode").on_press_maybe(if app.is_encoding || app.command_queue.is_empty() { None } else { Some(Message::Encode) }), button("Abort").on_press_maybe(if app.is_encoding { Some(Message::Abort) } else { None }), button("Clear Queue").on_press_maybe(if app.is_encoding { None } else { Some(Message::ClearCommandQueue) }), ].spacing(10); column![controls, queue_list.height(Length::Fill), text("Encoding Progress:"), progress_bar(0.0..=100.0, app.encode_progress)].spacing(20).into() }
fn view_about_tab(app: &CykoApp) -> Element<Message> { column![ text("Cyko - Rust Edition").size(30), text("A modern, cross-platform rewrite of the original Cyko batch encoder."), rule::Rule::horizontal(10), text(format!("Using: {}", app.handbrake_version)), ].spacing(15).align_items(Alignment::Center).into() }
fn view_options_tab(app: &CykoApp) -> Element<Message> { let is_disabled = app.is_encoding; let on_press_if = |msg| if is_disabled { None } else { Some(msg) }; let quality_options = column![ text("Encoder & Quality").size(20), text("Encoder:"), pick_list(app.available_encoders.clone(), Some(app.encoder), Message::EncoderChanged), text("Mode:"), pick_list(MODES.to_vec(), Some(app.mode), Message::ModeChanged), text_input("Video Quality/Bitrate", &app.video_value).on_input(Message::VideoValueChanged), text_input("Audio Bitrate (kbps)", &app.audio_value).on_input(Message::AudioValueChanged), ].spacing(10); let advanced_options = column![ text("Advanced Encoding").size(20), text("Encoder Profile:"), text_input("e.g. high, main, baseline", &app.encoder_profile).on_input(Message::EncoderProfileChanged), text("Encoder Level:"), text_input("e.g. 4.1, 5.0", &app.encoder_level).on_input(Message::EncoderLevelChanged), text("Extra Options (-x):"), text_input("e.g. option1=value1:option2=value2", &app.encopts).on_input(Message::EncoptsChanged), ].spacing(10); let pass_rate_options = column![ text("Pass & Rate Control").size(20), check_box("Multi-pass", app.multi_pass, Message::MultiPassChanged), check_box("Turbo first pass", app.turbo, Message::TurboChanged), check_box("Enable HW Decoding", app.hw_decoding, Message::HwDecodingChanged), row![ text("Framerate:"), text_input("e.g. 30, 29.97", &app.framerate).on_input(Message::FramerateChanged), pick_list(FRAMERATE_MODES.to_vec(), Some(app.framerate_mode), Message::FramerateModeChanged), ].spacing(10), ].spacing(10); let other_options = column![ text("Output & Subtitles").size(20), row![ text("Resolution:"), text_input("Height/Width", &app.resolution_value).on_input(Message::ResolutionChanged), toggler(Some(if app.is_width_resolution {"Width"} else {"Height"}.to_string()), app.is_width_resolution, Message::ResolutionToggleChanged), ].spacing(10).align_items(Alignment::Center), check_box("Burn subtitles (Hard Subs)", app.hard_subs, Message::HardSubsChanged), check_box("Show Console Window", app.show_console, Message::ShowConsoleChanged), check_box("Shutdown when done", app.shutdown_after_done, Message::ShutdownChanged), ].spacing(10); let output_dir_options = row![ text("Output Directory:"), text(&app.output_dir).width(Length::Fill), button("Select...").on_press(Message::SelectOutputDirectory), ].spacing(10).align_items(Alignment::Center); let main_controls = row![button("Enqueue").on_press(Message::Enqueue).padding(15)].spacing(10); let full_options = if is_disabled { column![quality_options, rule::Rule::horizontal(20), advanced_options, rule::Rule::horizontal(20), pass_rate_options, rule::Rule::horizontal(20), other_options, rule::Rule::horizontal(20), output_dir_options, main_controls].spacing(15).map(|_| Message::EventOccurred(Event::Mouse(iced::mouse::Event::ButtonPressed(iced::mouse::Button::Left)))) } else { column![quality_options, rule::Rule::horizontal(20), advanced_options, rule::Rule::horizontal(20), pass_rate_options, rule::Rule::horizontal(20), other_options, rule::Rule::horizontal(20), output_dir_options, main_controls].spacing(15) }; scrollable(full_options).into() }
