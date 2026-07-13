% MATLAB Base Station for RSSI Positioning
% Reads serial from gateway: format "rssi0,rssi1,rssi2"

clear; clc; close all;

% --- Serial setup ---
serialPort = 'COM3';            % Change to your port (e.g., '/dev/ttyUSB0' on Linux)
baudRate = 115200;
s = serialport(serialPort, baudRate);
s.Timeout = 1;                  % seconds

% --- Path-loss parameters (empirically measured) ---
RSSI_0 = -40;                   % RSSI at 1 metre (in dBm)
n = 2.2;                        % Path-loss exponent (adjust to your environment)
d0 = 1;                         % reference distance

% --- Anchor positions (in meters) ---
% Define three anchors in a triangle (example)
anchors = [0, 0;      % anchor 0 at (0,0)
    4, 0;      % anchor 1 at (4,0)
    2, 4];     % anchor 2 at (2,4)

% --- Kalman filter initialization ---
% State: [x; y; vx; vy] (position and velocity)
dt = 0.1;                       % time step (s)
F = [1, 0, dt, 0;
    0, 1, 0, dt;
    0, 0, 1, 0;
    0, 0, 0, 1];
H = [1, 0, 0, 0; 0, 1, 0, 0];   % we measure only position
Q = diag([0.01, 0.01, 0.01, 0.01]);  % process noise covariance
R = diag([0.5, 0.5]);                % measurement noise covariance (tune)
x_est = [2; 2; 0; 0];           % initial state guess
P = eye(4);                     % initial covariance

% --- Storage for plotting ---
estimated_positions = [];
true_positions = [];           % if you have ground truth

% --- Main loop ---
fprintf('Reading serial data... Press Ctrl+C to stop.\n');
while true
    % Read a line from serial (blocking until newline or timeout)
    line = readline(s);
    if isempty(line)
        continue;
    end

    % Parse RSSI values
    tokens = strsplit(strtrim(line), ',');
    if length(tokens) ~= 3
        continue;
    end
    rssi = str2double(tokens);

    % Convert each RSSI to distance using log-distance model
    distances = d0 * 10.^((RSSI_0 - rssi) / (10 * n));

    % --- Perform trilateration (least squares) ---
    % We solve for (x,y) that minimizes sum of squared errors:
    % (x-ax)^2 + (y-ay)^2 = d^2
    % Linearize: 2*(ax - a_ref)*x + 2*(ay - a_ref)*y = d_ref^2 - d^2 + ax^2 - a_ref^2 + ay^2 - a_ref^2
    % Use anchor 0 as reference.
    ref = 1;                    % 1-based index in MATLAB
    A = 2 * (anchors - anchors(ref,:));
    b = distances(ref)^2 - distances.^2 + sum(anchors.^2, 2) - sum(anchors(ref,:).^2, 2);
    % A is Nx2, b is Nx1; solve least squares
    pos = (A' * A) \ (A' * b);

    % --- Kalman filter update ---
    % Predict
    x_pred = F * x_est;
    P_pred = F * P * F' + Q;

    % Update with measurement
    z = pos;                    % measurement vector (x,y)
    K = P_pred * H' / (H * P_pred * H' + R);
    x_est = x_pred + K * (z - H * x_pred);
    P = (eye(4) - K * H) * P_pred;

    % Store filtered position
    estimated_positions = [estimated_positions; x_est(1:2)'];

    % --- Plot live ---
    plot(anchors(:,1), anchors(:,2), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
    hold on;
    plot(estimated_positions(:,1), estimated_positions(:,2), 'b-', 'LineWidth', 1);
    plot(estimated_positions(end,1), estimated_positions(end,2), 'bx', 'MarkerSize', 8);
    legend('Anchors', 'Path', 'Current estimate');
    xlabel('X (m)'); ylabel('Y (m)');
    axis([-1 5 -1 5]);
    grid on;
    hold off;
    drawnow;
end