//
//  ViewController.m
//  whisper.objc
//
//  Created by Georgi Gerganov on 23.10.22.
//

#import "ViewController.h"

#import "whisper.h"

#define NUM_BYTES_PER_BUFFER 16*1024

// callback used to process captured audio
void AudioInputCallback(void * inUserData,
                        AudioQueueRef inAQ,
                        AudioQueueBufferRef inBuffer,
                        const AudioTimeStamp * inStartTime,
                        UInt32 inNumberPacketDescriptions,
                        const AudioStreamPacketDescription * inPacketDescs);

@interface ViewController () <UIPickerViewDelegate, UIPickerViewDataSource>

@property (weak, nonatomic) IBOutlet UILabel    *labelStatusInp;
@property (weak, nonatomic) IBOutlet UIButton   *buttonToggleCapture;
@property (weak, nonatomic) IBOutlet UIButton   *buttonTranscribe;
@property (weak, nonatomic) IBOutlet UIPickerView *pickerViewLanguage;
@property (weak, nonatomic) IBOutlet UITextView *textviewResult;

@property (weak, nonatomic) IBOutlet UISwitch *switchRealtime;
- (IBAction)switchRealtime:(id)sender;

@property (weak, nonatomic) IBOutlet UISwitch *switchTranslate;
- (IBAction)switchTranslate:(id)sender;

@property (strong, nonatomic) NSDictionary *languageMap;
@property (strong, nonatomic) NSArray *languageKeys;

@end

@implementation ViewController

- (void)setupAudioFormat:(AudioStreamBasicDescription*)format
{
    format->mSampleRate       = WHISPER_SAMPLE_RATE;
    format->mFormatID         = kAudioFormatLinearPCM;
    format->mFramesPerPacket  = 1;
    format->mChannelsPerFrame = 1;
    format->mBytesPerFrame    = 2;
    format->mBytesPerPacket   = 2;
    format->mBitsPerChannel   = 16;
    format->mReserved         = 0;
    format->mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // whisper.cpp initialization
    {
        // load the model
        NSString *modelPath = [[NSBundle mainBundle] pathForResource:@"ggml-small" ofType:@"bin"];

        // check if the model exists
        if (![[NSFileManager defaultManager] fileExistsAtPath:modelPath]) {
            NSLog(@"Model file not found");
            return;
        }

        NSLog(@"Loading model from %@", modelPath);

        // create ggml context
        stateInp.ctx = whisper_init_from_file([modelPath UTF8String]);

        // check if the model was loaded successfully
        if (stateInp.ctx == NULL) {
            NSLog(@"Failed to load model");
            return;
        }
    }

    // initialize audio format and buffers
    {
        [self setupAudioFormat:&stateInp.dataFormat];

        stateInp.n_samples = 0;
        stateInp.audioBufferI16 = malloc(MAX_AUDIO_SEC*SAMPLE_RATE*sizeof(int16_t));
        stateInp.audioBufferF32 = malloc(MAX_AUDIO_SEC*SAMPLE_RATE*sizeof(float));
    }

    stateInp.isTranscribing = false;
    stateInp.isRealtime = true;
    stateInp.translate = false;

    stateInp.language = "en";
    self.languageMap = @{@"english": @"en", @"chinese": @"zh", @"german": @"de", @"spanish": @"es", @"russian": @"ru", @"korean": @"ko", @"french": @"fr", @"japanese": @"ja", @"portuguese": @"pt", @"turkish": @"tr", @"polish": @"pl", @"catalan": @"ca", @"dutch": @"nl", @"arabic": @"ar", @"swedish": @"sv", @"italian": @"it", @"indonesian": @"id", @"hindi": @"hi", @"finnish": @"fi", @"vietnamese": @"vi", @"hebrew": @"he", @"ukrainian": @"uk", @"greek": @"el", @"malay": @"ms", @"czech": @"cs", @"romanian": @"ro", @"danish": @"da", @"hungarian": @"hu", @"tamil": @"ta", @"norwegian": @"no", @"thai": @"th", @"urdu": @"ur", @"croatian": @"hr", @"bulgarian": @"bg", @"lithuanian": @"lt", @"latin": @"la", @"maori": @"mi", @"malayalam": @"ml", @"welsh": @"cy", @"slovak": @"sk", @"telugu": @"te", @"persian": @"fa", @"latvian": @"lv", @"bengali": @"bn", @"serbian": @"sr", @"azerbaijani": @"az", @"slovenian": @"sl", @"kannada": @"kn", @"estonian": @"et", @"macedonian": @"mk", @"breton": @"br", @"basque": @"eu", @"icelandic": @"is", @"armenian": @"hy", @"nepali": @"ne", @"mongolian": @"mn", @"bosnian": @"bs", @"kazakh": @"kk", @"albanian": @"sq", @"swahili": @"sw", @"galician": @"gl", @"marathi": @"mr", @"punjabi": @"pa", @"sinhala": @"si", @"khmer": @"km", @"shona": @"sn", @"yoruba": @"yo", @"somali": @"so", @"afrikaans": @"af", @"occitan": @"oc", @"georgian": @"ka", @"belarusian": @"be", @"tajik": @"tg", @"sindhi": @"sd", @"gujarati": @"gu", @"amharic": @"am", @"yiddish": @"yi", @"lao": @"lo", @"uzbek": @"uz", @"faroese": @"fo", @"haitian_creole": @"ht", @"pashto": @"ps", @"turkmen": @"tk", @"nynorsk": @"nn", @"maltese": @"mt", @"sanskrit": @"sa", @"luxembourgish": @"lb", @"myanmar": @"my", @"tibetan": @"bo", @"tagalog": @"tl", @"malagasy": @"mg", @"assamese": @"as", @"tatar": @"tt", @"hawaiian": @"haw", @"lingala": @"ln", @"hausa": @"ha", @"bashkir": @"ba", @"javanese": @"jw", @"sundanese": @"su"};
    self.languageKeys = @[@"english", @"german", @"japanese", @"afrikaans", @"albanian", @"amharic", @"arabic", @"armenian", @"assamese", @"azerbaijani", @"bashkir", @"basque", @"belarusian", @"bengali", @"bosnian", @"breton", @"bulgarian", @"catalan", @"chinese", @"croatian", @"czech", @"danish", @"dutch", @"estonian", @"faroese", @"finnish", @"french", @"galician", @"georgian", @"greek", @"gujarati", @"haitian_creole", @"hausa", @"hawaiian", @"hebrew", @"hindi", @"hungarian", @"icelandic", @"indonesian", @"italian", @"javanese", @"kannada", @"kazakh", @"khmer", @"korean", @"lao", @"latin", @"latvian", @"lingala", @"lithuanian", @"luxembourgish", @"macedonian", @"malagasy", @"malay", @"malayalam", @"maltese", @"maori", @"marathi", @"mongolian", @"myanmar", @"nepali", @"norwegian", @"nynorsk", @"occitan", @"pashto", @"persian", @"polish", @"portuguese", @"punjabi", @"romanian", @"russian", @"sanskrit", @"serbian", @"shona", @"sindhi", @"sinhala", @"slovak", @"slovenian", @"somali", @"spanish", @"sundanese", @"swahili", @"swedish", @"tagalog", @"tajik", @"tamil", @"tatar", @"telugu", @"thai", @"tibetan", @"turkish", @"turkmen", @"ukrainian", @"urdu", @"uzbek", @"vietnamese", @"welsh", @"yiddish", @"yoruba"];
    self.pickerViewLanguage.delegate = self;
    self.pickerViewLanguage.dataSource = self;

}

-(IBAction) stopCapturing {
    NSLog(@"Stop capturing");

    _labelStatusInp.text = @"Status: Idle";

    [_buttonToggleCapture setTitle:@"Start capturing" forState:UIControlStateNormal];
    [_buttonToggleCapture setBackgroundColor:[UIColor grayColor]];

    stateInp.isCapturing = false;

    AudioQueueStop(stateInp.queue, true);
    for (int i = 0; i < NUM_BUFFERS; i++) {
        AudioQueueFreeBuffer(stateInp.queue, stateInp.buffers[i]);
    }

    AudioQueueDispose(stateInp.queue, true);
}

- (IBAction)toggleCapture:(id)sender {
    if (stateInp.isCapturing) {
        // stop capturing
        [self stopCapturing];

        return;
    }

    // initiate audio capturing
    NSLog(@"Start capturing");

    stateInp.n_samples = 0;
    stateInp.vc = (__bridge void *)(self);

    OSStatus status = AudioQueueNewInput(&stateInp.dataFormat,
                                         AudioInputCallback,
                                         &stateInp,
                                         CFRunLoopGetCurrent(),
                                         kCFRunLoopCommonModes,
                                         0,
                                         &stateInp.queue);

    if (status == 0) {
        for (int i = 0; i < NUM_BUFFERS; i++) {
            AudioQueueAllocateBuffer(stateInp.queue, NUM_BYTES_PER_BUFFER, &stateInp.buffers[i]);
            AudioQueueEnqueueBuffer (stateInp.queue, stateInp.buffers[i], 0, NULL);
        }

        stateInp.isCapturing = true;
        status = AudioQueueStart(stateInp.queue, NULL);
        if (status == 0) {
            _labelStatusInp.text = @"Status: Capturing";
            [sender setTitle:@"Stop Capturing" forState:UIControlStateNormal];
            [_buttonToggleCapture setBackgroundColor:[UIColor redColor]];
        }
    }

    if (status != 0) {
        [self stopCapturing];
    }
}

- (IBAction)onTranscribePrepare:(id)sender {
    _textviewResult.text = @"Processing - please wait ...";

    if (stateInp.isRealtime) {
        [self.switchRealtime setOn:NO animated:YES];
        [self switchRealtime:self.switchRealtime];
    }

    if (stateInp.isCapturing) {
        [self stopCapturing];
    }
}

- (IBAction)switchRealtime:(UISwitch *)sender {
    stateInp.isRealtime = sender.isOn;
}

- (IBAction)switchTranslate:(UISwitch *)sender {
    stateInp.translate = sender.isOn;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [self.languageKeys count];
}

- (NSString*)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return self.languageKeys[row];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    NSString *selectedLanguageKey = self.languageKeys[row];
    stateInp.language = strdup([self.languageMap[selectedLanguageKey] UTF8String]);
}

- (IBAction)onTranscribe:(id)sender {
    if (stateInp.isTranscribing) {
        return;
    }

    NSLog(@"Processing %d samples", stateInp.n_samples);

    stateInp.isTranscribing = true;

    // dispatch the model to a background thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // process captured audio
        // convert I16 to F32
        for (int i = 0; i < self->stateInp.n_samples; i++) {
            self->stateInp.audioBufferF32[i] = (float)self->stateInp.audioBufferI16[i] / 32768.0f;
        }

        // run the model
        struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);

        // get maximum number of threads on this device (max 8)
        const int max_threads = MIN(8, (int)[[NSProcessInfo processInfo] processorCount]);

        params.print_realtime   = true;
        params.print_progress   = false;
        params.print_timestamps = true;
        params.print_special    = false;
        params.translate        = self->stateInp.translate;
        params.language         = self->stateInp.language;
        params.n_threads        = max_threads;
        params.offset_ms        = 0;
        params.no_context       = true;
        params.single_segment   = self->stateInp.isRealtime;

        CFTimeInterval startTime = CACurrentMediaTime();

        whisper_reset_timings(self->stateInp.ctx);

        if (whisper_full(self->stateInp.ctx, params, self->stateInp.audioBufferF32, self->stateInp.n_samples) != 0) {
            NSLog(@"Failed to run the model");
            self->_textviewResult.text = @"Failed to run the model";

            return;
        }

        whisper_print_timings(self->stateInp.ctx);

        CFTimeInterval endTime = CACurrentMediaTime();

        NSLog(@"\nProcessing time: %5.3f, on %d threads", endTime - startTime, params.n_threads);

        // result text
        NSString *result = @"";

        int n_segments = whisper_full_n_segments(self->stateInp.ctx);
        for (int i = 0; i < n_segments; i++) {
            const char * text_cur = whisper_full_get_segment_text(self->stateInp.ctx, i);

            // append the text to the result
            result = [result stringByAppendingString:[NSString stringWithUTF8String:text_cur]];
        }

        const float tRecording = (float)self->stateInp.n_samples / (float)self->stateInp.dataFormat.mSampleRate;

        // append processing time
        result = [result stringByAppendingString:[NSString stringWithFormat:@"\n\n[recording time:  %5.3f s]", tRecording]];
        result = [result stringByAppendingString:[NSString stringWithFormat:@"  \n[processing time: %5.3f s]", endTime - startTime]];

        // dispatch the result to the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_textviewResult.text = result;
            self->stateInp.isTranscribing = false;
        });
    });
}

//
// Callback implementation
//

void AudioInputCallback(void * inUserData,
                        AudioQueueRef inAQ,
                        AudioQueueBufferRef inBuffer,
                        const AudioTimeStamp * inStartTime,
                        UInt32 inNumberPacketDescriptions,
                        const AudioStreamPacketDescription * inPacketDescs)
{
    StateInp * stateInp = (StateInp*)inUserData;

    if (!stateInp->isCapturing) {
        NSLog(@"Not capturing, ignoring audio");
        return;
    }

    const int n = inBuffer->mAudioDataByteSize / 2;

    NSLog(@"Captured %d new samples", n);

    if (stateInp->n_samples + n > MAX_AUDIO_SEC*SAMPLE_RATE) {
        NSLog(@"Too much audio data, ignoring");

        dispatch_async(dispatch_get_main_queue(), ^{
            ViewController * vc = (__bridge ViewController *)(stateInp->vc);
            [vc stopCapturing];
        });

        return;
    }

    for (int i = 0; i < n; i++) {
        stateInp->audioBufferI16[stateInp->n_samples + i] = ((short*)inBuffer->mAudioData)[i];
    }

    stateInp->n_samples += n;

    // put the buffer back in the queue
    AudioQueueEnqueueBuffer(stateInp->queue, inBuffer, 0, NULL);

    if (stateInp->isRealtime) {
        // dipatch onTranscribe() to the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            ViewController * vc = (__bridge ViewController *)(stateInp->vc);
            [vc onTranscribe:nil];
        });
    }
}

@end
