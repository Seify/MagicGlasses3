//
//  MGViewController.m
//  MagicGlasses2
//
//  Created by Roman Smirnov on 18.11.12.
//  Copyright (c) 2012 Roman Smirnov. All rights reserved.
//

#import <CoreVideo/CVOpenGLESTextureCache.h>
#import "MGViewController.h"
#import "ResourceManager.h"
#import "matrix.h"
#import "models.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

#define SCREEN_WIDTH [[UIScreen mainScreen] bounds].size.width
#define SCREEN_HEIGHT [[UIScreen mainScreen] bounds].size.height

#define degreeToRadians M_PI/180*
#define radiansToDegree 180/M_PI*

@interface MGViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    CVOpenGLESTextureRef videoTexture;
    
    NSString *sessionPreset;
    
    AVCaptureSession *session;
    
    CVOpenGLESTextureCacheRef videoTextureCache;
    
    GLKTextureInfo *backgroundTexture;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

- (void)setupGL;
- (void)tearDownGL;

@end

@implementation MGViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [self setupGL];
    
    [self setupAVCapture];
}

- (void)dealloc
{
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }
    
    // Dispose of any resources that can be recreated.
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    // load textures
    
    NSError *err;
    backgroundTexture = [GLKTextureLoader textureWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Doom-Sky" ofType:@"jpg" inDirectory:@"/Textures"]
                                                            options:nil
                                                              error:&err];
    
    if (err)
        NSLog(@"error = %@", err);
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
}

- (void)setupAVCapture
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        // Choosing bigger preset for bigger screen.
        sessionPreset = AVCaptureSessionPreset1280x720;
    }
    else
    {
        sessionPreset = AVCaptureSessionPreset640x480;
    }
    
    //-- Create CVOpenGLESTextureCacheRef for optimal CVImageBufferRef to GLES texture conversion.
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, (__bridge CVEAGLContext)((__bridge void *)_context), NULL, &videoTextureCache);
    if (err)
    {
        NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
        return;
    }
    
    //-- Setup Capture Session.
    session = [[AVCaptureSession alloc] init];
    [session beginConfiguration];
    
    //-- Set preset session size.
    [session setSessionPreset:sessionPreset];
    
    //-- Creata a video device and input from that Device.  Add the input to the capture session.
    AVCaptureDevice * videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if(videoDevice == nil)
        assert(0);
    
    //-- Add the device to the session.
    NSError *error;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if(error)
        assert(0);
    
    [session addInput:input];
    
    //-- Create the output for the capture session.
    AVCaptureVideoDataOutput * dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [dataOutput setAlwaysDiscardsLateVideoFrames:YES]; // Probably want to set this to NO when recording
    
    [dataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                                             forKey:(id)kCVPixelBufferPixelFormatTypeKey]]; // Necessary for manual preview
    
    // Set dispatch to be on the main thread so OpenGL can do things with the data
    [dataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    [session addOutput:dataOutput];
    [session commitConfiguration];
    
    [session startRunning];
}

- (void)cleanUpTextures
{
    if (videoTexture)
    {
        CFRelease(videoTexture);
        videoTexture = NULL;
    }
    
    // Periodic texture cache flush every frame
    CVOpenGLESTextureCacheFlush(videoTextureCache, 0);
}


- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    
    CVReturn err;
	CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    if (!videoTextureCache)
    {
        NSLog(@"No video texture cache");
        return;
    }
    
    [self cleanUpTextures];
    
    // CVOpenGLESTextureCacheCreateTextureFromImage will create GLES texture
    // optimally from CVImageBufferRef.
    
    glActiveTexture(GL_TEXTURE0);
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       videoTextureCache,
                                                       pixelBuffer,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_RGBA,
                                                       width,
                                                       height,
                                                       GL_RGBA,
                                                       GL_UNSIGNED_BYTE,
                                                       0,
                                                       &videoTexture);
    if (err)
    {
        NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    
    glBindTexture(CVOpenGLESTextureGetTarget(videoTexture), CVOpenGLESTextureGetName(videoTexture));
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}


#pragma mark - Matrices business

- (void)MakeMatrix:(GLfloat *) matrix OriginX:(GLfloat)originX OriginY:(GLfloat)originY Width:(GLfloat)width Height:(GLfloat)height Rotation:(GLfloat)rot{
    
    GLfloat rotationMatrix[16], translationMatrix[16], scaleMatrix[16], tempMatrix[16], proj[16], modelview[16];
    
    float lowerLeftCornerOffsetX = -(SCREEN_WIDTH-width)/SCREEN_WIDTH;
    float lowerLeftCornerOffsetY = (SCREEN_HEIGHT-height)/SCREEN_HEIGHT;
    
    mat4f_LoadXYZTranslation(lowerLeftCornerOffsetX + originX*2.0/SCREEN_WIDTH, lowerLeftCornerOffsetY - ( originY*2.0)/SCREEN_HEIGHT, -90.0f, translationMatrix);
    mat4f_LoadXYZRotation(degreeToRadians(90 + rot), 0.0f, 0.0f, rotationMatrix);
    mat4f_LoadXYZScale(width/SCREEN_WIDTH, height/SCREEN_HEIGHT, 1.0f, scaleMatrix);
    mat4f_LoadOrtho(-1.0, 1.0, -1.0, 1.0, -100.0f, 100.0f, proj);
    mat4f_MultiplyMat4f(translationMatrix, scaleMatrix, tempMatrix);
    mat4f_MultiplyMat4f(tempMatrix, rotationMatrix, modelview);
    mat4f_MultiplyMat4f(proj, modelview, matrix);
}

- (void)MakePerspectiveMatrix:(GLfloat *) matrix
                      OriginX:(GLfloat)originX
                      OriginY:(GLfloat)originY
                        Width:(GLfloat)width
                       Height:(GLfloat)height
                     Rotation:(GLfloat)rot
                 TranslationX:(GLfloat)transX
                 TranslationY:(GLfloat)transY
                 TranslationZ:(GLfloat)transZ
                       ScaleX:(CGFloat)scaleX
                       ScaleY:(CGFloat)scaleY
{
    
    GLfloat rotationMatrix[16], translationMatrix[16], scaleMatrix[16], proj[16];
    
    float lowerLeftCornerOffsetX = -(SCREEN_WIDTH-width)/SCREEN_WIDTH;
    float lowerLeftCornerOffsetY = (SCREEN_HEIGHT-height)/SCREEN_HEIGHT;
    
    mat4f_LoadXYZTranslation(lowerLeftCornerOffsetX + originX*2.0/SCREEN_WIDTH + transX, lowerLeftCornerOffsetY - ( originY*2.0)/SCREEN_HEIGHT + transY, -50.0f + transZ, translationMatrix);
    mat4f_LoadXYZRotation(0.0f, degreeToRadians(rot), 0.0f, rotationMatrix);
    mat4f_LoadXYZScale(width/SCREEN_WIDTH * scaleX * 5.0, height/SCREEN_HEIGHT * scaleY * 5.0, 1.0f, scaleMatrix);
    mat4f_LoadPerspective(degreeToRadians(100), (width/height), 20.0, 80.0, proj);
    
    makePerspectiveMatrix(scaleMatrix, translationMatrix, rotationMatrix, proj, matrix);
}

#pragma mark - Drawing Cycle

- (void)drawVideoFrame
{
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_BLEND);
    
//    GLuint currentProgram = [[ResourceManager sharedInstance] getProgram:PROGRAM_SIMPLE_TEXTURING];
    GLuint currentProgram = [[ResourceManager sharedInstance] getProgram:PROGRAM_DRAW_VIDEO_FRAME];
    glUseProgram(currentProgram);
    
    GLfloat modelviewProj[16];
    [self MakeMatrix:modelviewProj
             OriginX:0.0
             OriginY:0.0
               Width:768.0
              Height:1024.0
            Rotation:0.0];
    
    // update uniform values
//    glUniformMatrix4fv(simple_texturing_uniforms[SIMPLE_TEXTURING_UNIFORM_MODEL_VIEW_PROJECTION_MATRIX], 1, GL_FALSE, modelviewProj);
    glUniformMatrix4fv(draw_video_frame_uniforms[DRAW_VIDEO_FRAME_UNIFORM_MODEL_VIEW_PROJECTION_MATRIX], 1, GL_FALSE, modelviewProj);
    
    if (videoTexture)
    {
        glActiveTexture(GL_TEXTURE0);
        //    glBindTexture(GL_TEXTURE_2D, backgroundTexture.name);
        
        glBindTexture(CVOpenGLESTextureGetTarget(videoTexture), CVOpenGLESTextureGetName(videoTexture));
//        glUniform1i(simple_texturing_uniforms[SIMPLE_TEXTURING_UNIFORM_TEXTURE], 0);
        glUniform1i(draw_video_frame_uniforms[DRAW_VIDEO_FRAME_UNIFORM_TEXTURE], 0);
        
    }
    
    
//    glVertexAttribPointer(SIMPLE_TEXTURING_ATTRIB_VERTEX,3, GL_FLOAT, GL_FALSE, sizeof(vertexDataTextured), &plain[0].vertex);
//    glEnableVertexAttribArray(SIMPLE_TEXTURING_ATTRIB_VERTEX);
//    
//    glVertexAttribPointer(SIMPLE_TEXTURING_ATTRIB_TEX_COORDS, 2, GL_FLOAT, GL_FALSE, sizeof(vertexDataTextured), &plain[0].texCoord);
//    glEnableVertexAttribArray(SIMPLE_TEXTURING_ATTRIB_TEX_COORDS);

    glVertexAttribPointer(DRAW_VIDEO_FRAME_ATTRIB_VERTEX,3, GL_FLOAT, GL_FALSE, sizeof(vertexDataTextured), &plain[0].vertex);
    glEnableVertexAttribArray(DRAW_VIDEO_FRAME_ATTRIB_VERTEX);
    
    glVertexAttribPointer(DRAW_VIDEO_FRAME_ATTRIB_TEX_COORDS, 2, GL_FLOAT, GL_FALSE, sizeof(vertexDataTextured), &plain[0].texCoord);
    glEnableVertexAttribArray(DRAW_VIDEO_FRAME_ATTRIB_TEX_COORDS);

    
    glDrawArrays(GL_TRIANGLES, 0, 6);
    
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    [self drawVideoFrame];
}



@end
