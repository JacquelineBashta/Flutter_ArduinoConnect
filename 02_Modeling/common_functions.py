
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

sns.set_style("darkgrid")


# Get data file names
START_T_COUNT = 0
START_F_COUNT = 500

SPLIT_T_RATIO = 0.7

NUM_NO_FEAT_COLUMN = 3

# Define the fixed window length and the overlap ratio
SMALLEST_DS_SIZE = 100
SEQUENCE_SIZE = 100 # 1sec
OVERLAP_PCT = 0.5  # 50% overlap ie 25 rows or 0.5sec


# Calculate the step size for the sliding window
step_size = int(SEQUENCE_SIZE * (1 - OVERLAP_PCT))


def data_split_TrainTest(df):
    num_t_ds = len(df.query("action_num < @START_F_COUNT").action.unique())
    num_f_ds = len(df.query("action_num >= @START_F_COUNT").action.unique())

    num_train_t = round(num_t_ds * SPLIT_T_RATIO)
    num_train_f = round(num_f_ds * SPLIT_T_RATIO)

    train_df = df[(df.action_num.between(START_T_COUNT,START_T_COUNT+num_train_t,inclusive="both"))|
                    (df.action_num.between(START_F_COUNT,START_F_COUNT+num_train_f,inclusive="both"))]

    test_df = df[(df.action_num.between(START_T_COUNT+num_train_t,START_F_COUNT,inclusive="neither"))|
                    (df.action_num > START_F_COUNT+num_train_f)]
    

    return train_df,test_df



def data_split_FeatLabel(df):
    X = df.iloc[:,:(-1*NUM_NO_FEAT_COLUMN)]
    y = df.label
    return X,y

def fe_basic_features2(df):
    df_fe_1 = df.copy()
    df_fe_1.insert(0, 'accel_x', df_fe_1.acc_x + df_fe_1.grav_x)
    df_fe_1.insert(1, 'accel_y', df_fe_1.acc_y + df_fe_1.grav_y)
    df_fe_1.insert(2, 'accel_z', df_fe_1.acc_z + df_fe_1.grav_z)
    df_fe_1.insert(3, 'accel_norm', np.sqrt(df_fe_1.accel_x**2 + df_fe_1.accel_y**2 + df_fe_1.accel_z**2))
    df_fe_1 = df_fe_1.drop(["grav_x","grav_y","grav_z","or_x","or_y","or_z",'acc_x', 'acc_y', 'acc_z'], axis=1)
    return df_fe_1

def fe_basic_features(df):
    df_fe_1 = df.copy()
    df_fe_1.insert(0, 'accel_x', df_fe_1.acc_x + df_fe_1.grav_x)
    df_fe_1.insert(1, 'accel_y', df_fe_1.acc_y + df_fe_1.grav_y)
    df_fe_1.insert(2, 'accel_z', df_fe_1.acc_z + df_fe_1.grav_z)
    df_fe_1.insert(3, 'accel_norm', np.sqrt(df_fe_1.accel_x**2 + df_fe_1.accel_y**2 + df_fe_1.accel_z**2))
    df_fe_1 = df_fe_1.drop(['accel_x', 'accel_y', 'accel_z'], axis=1)
    return df_fe_1



def fe_lag_features(df,n_lagwindow, cols):
    """
    Parameters
    ----------
    n : int       amount of lag features
    cols : list   list of columns to lag

    Returns
    -------
    pd.DataFrame    a dataframe with the list of columns lagged n times
    """
    lag_df = df.copy()
    NUM_FEAT_COLUMNS = len(df.columns)- NUM_NO_FEAT_COLUMN
    for j in cols:
        for i in range(n_lagwindow):
            lag_df.insert(NUM_FEAT_COLUMNS+i, j + '_lag' + str(i+1), lag_df[j].shift(i+1))
        
    # Dropping all rows where the lag overlapped two different subjects/trials (n timeframes at the beginning of every trial).
    for i in range(n_lagwindow):
        lag_df = lag_df.drop([i])
    
    return lag_df



# Creating rolling feature columns.

def fe_roll_features(df,k):
    """
    Parameters
    ----------
    k : int
        the amount of steps for the rolling features
    Returns
    -------
    pd.Dataframe
        a new dataframe with rolling features over k steps
    """
    
    feat_df = df.copy()
    cols = feat_df.iloc[:,:(-1*NUM_NO_FEAT_COLUMN)].columns

    j = 1
    for i in cols:
        feat_df.insert(j, f'{i}_rmean', feat_df[i].rolling(k).mean())
        feat_df.insert(j+1, f'{i}_rstd', feat_df[i].rolling(k).std())
        feat_df.insert(j+2, f'{i}_rmed', feat_df[i].rolling(k).median())
        #feat_df.insert(j+3, f'{i}_rskew', feat_df[i].rolling(k).skew())
        #feat_df.insert(j+4, f'{i}_rmax', feat_df[i].rolling(k).max())
        #feat_df.insert(j+5, f'{i}_rmin', feat_df[i].rolling(k).min())
        #feat_df.insert(j+6, f'{i}_squared', feat_df[i]**2)
        j += 4 

    # Dropping all rows where the lag overlapped two different subjects/trials.
    for i in range(k):
        feat_df = feat_df.drop([i])
    
    return feat_df



def fe_segmentation(df):
    window_size = 50    # time points per window

    # Segment the time series data into non-overlapping windows
    segments = []
    for i in range(0, len(df) - window_size, window_size):
        segment = df.iloc[i:i+window_size]
        segments.append(segment)

    # Extract features from the segmented data
    features = []
    for segment in segments:
        # Example feature extraction: mean and standard deviation
        feature = [segment['value'].mean(), segment['value'].std(), segment['value'].median()]
        features.append(feature)

    # Convert the features to a numpy array for further processing
    features_array = np.asarray(features)
     
    return  features_array


def pre_normalize_tanh(df):
    m = np.mean(df, axis=0) # array([16.25, 26.25])
    std = np.std(df, axis=0) # array([17.45530005, 22.18529919])

    data = 0.5 * (np.tanh(0.01 * ((df - m) / std)) + 1)
    return data

