//
//  ViewController.m
//  Project2
//
//  Created by Jinwoo Kim on 11/3/24.
//

#import "ViewController.h"
#import <CoreML/CoreML.h>
#import <Vision/Vision.h>
#import <PhotosUI/PhotosUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "HealthySnacks.h"

@interface ViewController () <PHPickerViewControllerDelegate>
@property (retain, nonatomic) IBOutlet UIImageView *imageView;
@property (retain, nonatomic) IBOutlet UILabel *label;
@property (retain, nonatomic, readonly) VNCoreMLRequest *healthySnacksRequest;
@property (retain, nonatomic, readonly) VNCoreMLRequest *multiSnacksRequest;
@end

@implementation ViewController
@synthesize healthySnacksRequest = _healthySnacksRequest;
@synthesize multiSnacksRequest = _multiSnacksRequest;

- (void)dealloc {
    [_healthySnacksRequest release];
    [_multiSnacksRequest release];
    [_imageView release];
    [_label release];
    [super dealloc];
}

- (VNCoreMLRequest *)healthySnacksRequest {
    if (_healthySnacksRequest) return _healthySnacksRequest;
    
    NSURL *assetURL = [NSBundle.mainBundle URLForResource:@"HealthySnacks" withExtension:@"mlmodelc"];
    MLModelConfiguration *configuration = [MLModelConfiguration new];
    NSError * _Nullable error = nil;
    MLModel *model = [MLModel modelWithContentsOfURL:assetURL configuration:configuration error:&error];
    [configuration release];
    assert(error == nil);
    
    VNCoreMLModel *visionModel = [VNCoreMLModel modelForMLModel:model error:&error];
    assert(error == nil);
    
    __weak typeof(self) weakSelf = self;
    
    VNCoreMLRequest *healthySnacksRequest = [[VNCoreMLRequest alloc] initWithModel:visionModel completionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                weakSelf.label.text = @"unknown error";
                return;
            }
            
            NSArray<VNClassificationObservation *> *results = request.results;
            
            if (results.count == 0) {
                weakSelf.label.text = @"nothing found";
            } else if (results[0].confidence < 0.8f) {
                weakSelf.label.text = @"not sure";
            } else {
                weakSelf.label.text = [NSString stringWithFormat:@"%@ %.1f%%", results[0].identifier, results[0].confidence * 100];
            }
        });
    }];
    
    healthySnacksRequest.imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop;
    
    _healthySnacksRequest = [healthySnacksRequest retain];
    return healthySnacksRequest;
}

- (VNCoreMLRequest *)multiSnacksRequest {
    if (_multiSnacksRequest) return _multiSnacksRequest;
    
    NSURL *assetURL = [NSBundle.mainBundle URLForResource:@"MultiSnacks" withExtension:@"mlmodelc"];
    MLModelConfiguration *configuration = [MLModelConfiguration new];
    NSError * _Nullable error = nil;
    MLModel *model = [MLModel modelWithContentsOfURL:assetURL configuration:configuration error:&error];
    [configuration release];
    assert(error == nil);
    
    VNCoreMLModel *visionModel = [VNCoreMLModel modelForMLModel:model error:&error];
    assert(error == nil);
    
    __weak typeof(self) weakSelf = self;
    
    VNCoreMLRequest *multiSnacksRequest = [[VNCoreMLRequest alloc] initWithModel:visionModel completionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                weakSelf.label.text = @"unknown error";
                return;
            }
            
            NSArray<VNClassificationObservation *> *results = request.results;
            
            if (results.count == 0) {
                weakSelf.label.text = @"nothing found";
            } else {
                NSMutableArray<NSString *> *strings = [[NSMutableArray alloc] initWithCapacity:MIN(3, results.count)];
                
                [results enumerateObjectsUsingBlock:^(VNClassificationObservation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if (idx == 2) {
                        *stop = YES;
                    }
                    
                    [strings addObject:[NSString stringWithFormat:@"%@ %.1f%%", obj.identifier, obj.confidence * 100]];
                }];
                
                weakSelf.label.text = [strings componentsJoinedByString:@"\n"];
            }
        });
    }];
    
    multiSnacksRequest.imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop;
    
    _multiSnacksRequest = [multiSnacksRequest retain];
    return multiSnacksRequest;
}

- (IBAction)pickImage:(UIBarButtonItem *)sender {
    PHPickerConfiguration *configuration = [PHPickerConfiguration new];
    configuration.filter = [PHPickerFilter imagesFilter];
    PHPickerViewController *viewController = [[PHPickerViewController alloc] initWithConfiguration:configuration];
    [configuration release];
    viewController.delegate = self;
    [self presentViewController:viewController animated:YES completion:nil];
    [viewController release];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    PHPickerResult * _Nullable firstResult = results.firstObject;
    if (firstResult == nil) return;
    
    [firstResult.itemProvider loadObjectOfClass:UIImage.class completionHandler:^(__kindof id<NSItemProviderReading>  _Nullable object, NSError * _Nullable error) {
        assert(error == nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImage *image = (UIImage *)object;
            self.imageView.image = object;
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Choose Model" message:nil preferredStyle:UIAlertControllerStyleAlert];
            
            [alertController addAction:[UIAlertAction actionWithTitle:@"Healthy Foods (VN)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    CIImage *ciImage = [[CIImage alloc] initWithImage:object];
                    assert(ciImage != nil);
                    
                    CGImagePropertyOrientation orientation = (CGImagePropertyOrientation)image.imageOrientation;
                    
                    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCIImage:ciImage orientation:orientation options:@{}];
                    [ciImage release];
                    
                    NSError * _Nullable error = nil;
                    [handler performRequests:@[self.healthySnacksRequest] error:&error];
                    [handler release];
                    assert(error == nil);
                });
            }]];
            
            [alertController addAction:[UIAlertAction actionWithTitle:@"Multi Foods (VN)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    CIImage *ciImage = [[CIImage alloc] initWithImage:object];
                    assert(ciImage != nil);
                    
                    CGImagePropertyOrientation orientation = (CGImagePropertyOrientation)image.imageOrientation;
                    
                    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCIImage:ciImage orientation:orientation options:@{}];
                    [ciImage release];
                    
                    NSError * _Nullable error = nil;
                    [handler performRequests:@[self.multiSnacksRequest] error:&error];
                    [handler release];
                    assert(error == nil);
                });
            }]];
            
            [alertController addAction:[UIAlertAction actionWithTitle:@"Healthy Foods (ML)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    NSURL *assetURL = [NSBundle.mainBundle URLForResource:@"HealthySnacks" withExtension:@"mlmodelc"];
                    MLModelConfiguration *configuration = [MLModelConfiguration new];
                    NSError * _Nullable error = nil;
                    MLModel *model = [MLModel modelWithContentsOfURL:assetURL configuration:configuration error:&error];
                    [configuration release];
                    assert(error == nil);
                    
                    //
                    
                    // pixel의 정보
                    MLImageConstraint *imageConstraint = model.modelDescription.inputDescriptionsByName[@"image"].imageConstraint;
                    assert(imageConstraint != nil);
                    
                    MLFeatureValue *featureValue = [MLFeatureValue featureValueWithCGImage:image.CGImage
                                                                                constraint:imageConstraint
                                                                                   options:@{
                        MLFeatureValueImageOptionCropAndScale: @(VNImageCropAndScaleOptionScaleFill)
                    }
                                                                                     error:&error];
                    assert(error == nil);
                    
//                    CVPixelBufferRef pixelBuffer = featureValue.imageBufferValue;
//                    assert(pixelBuffer != NULL);
                    
                    MLDictionaryFeatureProvider *provider = [[MLDictionaryFeatureProvider alloc] initWithDictionary:@{@"image": featureValue} error:&error];
                    assert(error == nil);
                    
                    MLPredictionOptions *options = [MLPredictionOptions new];
                    
                    MLDictionaryFeatureProvider *outFeatures = (MLDictionaryFeatureProvider *)[model predictionFromFeatures:provider options:options error:&error];
                    [provider release];
                    [options release];
                    assert(error == nil);
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.label.text = ((NSObject *)outFeatures).description;
                    });
                });
            }]];
            
            [alertController addAction:[UIAlertAction actionWithTitle:@"Mobile Net (ML)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    NSURL *assetURL = [NSBundle.mainBundle URLForResource:@"MobileNet" withExtension:@"mlmodelc"];
                    MLModelConfiguration *configuration = [MLModelConfiguration new];
                    NSError * _Nullable error = nil;
                    MLModel *model = [MLModel modelWithContentsOfURL:assetURL configuration:configuration error:&error];
                    [configuration release];
                    assert(error == nil);
                    
                    //
                    
                    // pixel의 정보
                    MLImageConstraint *imageConstraint = model.modelDescription.inputDescriptionsByName[@"image"].imageConstraint;
                    assert(imageConstraint != nil);
                    
                    MLFeatureValue *featureValue = [MLFeatureValue featureValueWithCGImage:image.CGImage
                                                                                constraint:imageConstraint
                                                                                   options:@{
                        MLFeatureValueImageOptionCropAndScale: @(VNImageCropAndScaleOptionScaleFill)
                    }
                                                                                     error:&error];
                    assert(error == nil);
                    
//                    CVPixelBufferRef pixelBuffer = featureValue.imageBufferValue;
//                    assert(pixelBuffer != NULL);
                    
                    MLDictionaryFeatureProvider *provider = [[MLDictionaryFeatureProvider alloc] initWithDictionary:@{@"image": featureValue} error:&error];
                    assert(error == nil);
                    
                    MLPredictionOptions *options = [MLPredictionOptions new];
                    
                    MLDictionaryFeatureProvider *outFeatures = (MLDictionaryFeatureProvider *)[model predictionFromFeatures:provider options:options error:&error];
                    [provider release];
                    [options release];
                    assert(error == nil);
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        MLFeatureValue *classLabel = outFeatures[@"classLabel"];
                        MLFeatureValue *classLabelProbs = outFeatures[@"classLabelProbs"];
                        self.label.text = [NSString stringWithFormat:@"%@", classLabelProbs.dictionaryValue[classLabel.stringValue]];
                    });
                });
            }]];
            
            [self presentViewController:alertController animated:YES completion:nil];
        });
    }];
}

@end
