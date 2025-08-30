use iced::futures;
use iced::futures::stream::Stream;
use std::path::PathBuf;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;
use tokio::sync::broadcast;

use crate::Progress;

pub fn encode(
    commands: Vec<String>,
    mut abort_receiver: broadcast::Receiver<()>,
) -> impl Stream<Item = Progress> {
    use futures::channel::mpsc;
    use futures::{SinkExt, StreamExt};
    use std::process::Stdio;

    let (mut sender, receiver) = mpsc::channel(100);

    tokio::spawn(async move {
        for command_str in commands {
            let mut child_process = if cfg!(target_os = "windows") {
                Command::new("cmd")
                    .args(["/C", &format!("HandBrakeCLI {}", command_str)])
                    .stdout(Stdio::piped())
                    .stderr(Stdio::piped())
                    .spawn()
            } else {
                Command::new("sh")
                    .arg("-c")
                    .arg(&format!("HandBrakeCLI {}", command_str))
                    .stdout(Stdio::piped())
                    .stderr(Stdio::piped())
                    .spawn()
            };

            let mut child = match child_process {
                Ok(child) => child,
                Err(e) => {
                    let _ = sender.send(Progress::Error(e.to_string())).await;
                    continue;
                }
            };

            let stdout = child.stdout.take().unwrap();
            let mut reader = BufReader::new(stdout).lines();

            let _ = sender.send(Progress::Started(command_str.clone())).await;

            loop {
                tokio::select! {
                    _ = abort_receiver.recv() => {
                        let _ = child.kill().await;
                        let _ = sender.send(Progress::Finished).await;
                        return;
                    }

                    line = reader.next_line() => {
                        match line {
                            Ok(Some(line)) => {
                                if line.contains("Encoding: task") {
                                    if let Some(progress_part) = line.split(',').nth(1) {
                                        if let Some(percent_str) = progress_part.trim().split(' ').next() {
                                            if let Ok(percent) = percent_str.parse::<f32>() {
                                                if sender.send(Progress::Updated(percent)).await.is_err() {
                                                    break;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            Ok(None) => break,
                            Err(_) => break,
                        }
                    }
                }
            }

            let status = child.wait().await;
            if let Err(e) = status {
                 let _ = sender.send(Progress::Error(e.to_string())).await;
            }
        }

        let _ = sender.send(Progress::AllFinished).await;
    });

    receiver
}

pub async fn scan_metadata(files: Vec<PathBuf>) -> Vec<(PathBuf, Result<f64, String>)> {
    let mut results = Vec::new();
    for file in files {
        let result = run_scan(&file).await;
        results.push((file, result));
    }
    results
}

async fn run_scan(path: &PathBuf) -> Result<f64, String> {
    let output = Command::new("HandBrakeCLI")
        .arg("-i")
        .arg(path.as_os_str())
        .arg("-t")
        .arg("0")
        .arg("--scan")
        .output()
        .await
        .map_err(|e| e.to_string())?;

    let text = String::from_utf8_lossy(&output.stderr);

    for line in text.lines() {
        if line.contains("+ duration:") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if let Some(time_str) = parts.get(2) {
                return parse_duration(time_str);
            }
        }
    }

    Err("Could not find duration in scan output.".to_string())
}

fn parse_duration(time_str: &str) -> Result<f64, String> {
    let time_parts: Vec<&str> = time_str.split(':').collect();
    if time_parts.len() != 3 {
        return Err(format!("Invalid time format: {}", time_str));
    }

    let hours = time_parts[0].parse::<f64>().map_err(|_| "Invalid hours".to_string())?;
    let minutes = time_parts[1].parse::<f64>().map_err(|_| "Invalid minutes".to_string())?;
    let seconds = time_parts[2].parse::<f64>().map_err(|_| "Invalid seconds".to_string())?;

    Ok((hours * 3600.0) + (minutes * 60.0) + seconds)
}
