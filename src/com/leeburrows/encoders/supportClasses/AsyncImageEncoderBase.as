/**
 * AsyncImageEncoderBase.as
 * Lee Burrows
 * version 1.0.0
 * 
 * Copyright (c) 2013 Lee Burrows
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
package com.leeburrows.encoders.supportClasses
{
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	
	/**
	 * Dispatched on each frame while encoder is running.
	 *
	 * @eventType com.leeburrows.encoders.supportClasses.AsyncImageEncoderEvent
	 */
	[Event(name="progress", type="com.leeburrows.encoders.supportClasses.AsyncImageEncoderEvent")]
	/**
	 *  Dispatched when encoding is complete.
	 *
	 *  @eventType flash.events.Event
	 */
	[Event(name="complete", type="flash.events.Event")]
	/** 
	 * This is the base class for all Asynchronous Image Encoders.
	 * 
	 * <p>Encodes BitmapData objects over multiple frames to avoid freezing the UI. Ideally suited for mobile AIR where ActionScript Workers are unavailable.</p>
	 * 
	 * <p>To implement your own encoder, create a subclass and override some or all of the core methods:</p>
	 * <ul>
	 * <li>initialise()</li>
	 * <li>encodeHead()</li>
	 * <li>encodeBlock()</li>
	 * <li>encodeTail()</li>
	 * </ul>
	 * <p>When a new instance is created <code>initialise()</code> is called once.</p>
	 * <p>When start is called:</p>
	 * <ol>
	 * <li>encodeHead() is called once.</li>
	 * <li>encodeBlock() is called repeatedly until it returns <code>true</code>.</li>
	 * <li>encoderTail() is called once.</li>
	 * </ol>
	 * 
	 * <p>In order to listen for Event.ENTER_FRAME, and dispatch progress and complete events, AsyncImageEncoderBase is a subclass of <code>flash.display.Sprite</code>. However, it does not need to be added to the display list to function.</p>
	 * 
	 * @langversion 3.0
	 * @playerversion Flash 9
	 * @playerversion AIR 1.5
	 */ 
	public class AsyncImageEncoderBase extends Sprite implements IAsyncImageEncoder
	{
		/**
		 * Internal storage for encoded bytes.
		 */
		protected var _encodedBytes:ByteArray = null;
		/**
		 * Internal storage for encoder status.
		 */
		protected var _isRunning:Boolean = false;
		/**
		 * BitmapData to be encoded.
		 */
		protected var sourceBitmapData:BitmapData;
		/**
		 * Horizontal size of BitmapData to be encoded.
		 */
		protected var sourceWidth:uint;
		/**
		 * Vertical size of BitmapData to be encoded.
		 */
		protected var sourceHeight:uint;
		/**
		 * Whether BitmapData supports transparency.
		 */
		protected var sourceTransparent:Boolean;
		/**
		 * Horizontal position of pixel currently being encoded.
		 */
		protected var currentX:uint;
		/**
		 * Vertical position of pixel currently being encoded.
		 */
		protected var currentY:uint;
		/**
		 * Number of pixels encoded.
		 */
		protected var completedPixels:uint;
		/**
		 * Total number of pixels to encode.
		 */
		protected var totalPixels:uint;
		
		private var frameTime:int;
		
		/**
		 * @inheritDoc
		 */
		public function get isRunning():Boolean
		{
			return _isRunning;
		}
		
		/**
		 * @inheritDoc
		 */
		public function get encodedBytes():ByteArray
		{
			if (_isRunning) return null;
			return _encodedBytes;
		}
		
		/**
		 * Creates a new <code>AsyncImageEncoderBase</code>.
		 * 
		 * <p>Do not use this class directly. Instead, create a subclass and override core methods.</p>
		 */
		public function AsyncImageEncoderBase()
		{
			super();
			initialise();
		}
		
		/**
		 * Called internally when instance is instantiated.
		 * 
		 * <p>Override to implement actions that only needs to be run once during initialisation.</p>
		 */
		protected function initialise():void
		{
		}
		
		/**
		 * @inheritDoc
		 */
		public function start(source:BitmapData, frameTime:int=20):void
		{
			sourceBitmapData = source.clone();
			this.frameTime = Math.max(1, frameTime);
			_isRunning = true;
			_encodedBytes = new ByteArray();
			sourceWidth = sourceBitmapData.width;
			sourceHeight = sourceBitmapData.height;
			sourceTransparent = sourceBitmapData.transparent;
			currentX = 0;
			currentY = 0;
			completedPixels = 0;
			totalPixels = sourceWidth*sourceHeight;
			encodeHead();
			addEventListener(Event.ENTER_FRAME, enterFrameHandler);
		}
		
		/**
		 * @inheritDoc
		 */
		public function stop():void
		{
			if (!_isRunning) return;
			cleanUp();
		}
		
		private function enterFrameHandler(event:Event):void
		{
			if (encodeBody())
			{
				encodeTail();
				cleanUp();
				dispatchEvent(new Event(Event.COMPLETE, false, false));
			}
			else
				dispatchEvent(new AsyncImageEncoderEvent(AsyncImageEncoderEvent.PROGRESS, completedPixels, totalPixels));
		}
		
		private function encodeBody():Boolean
		{
			var isComplete:Boolean = false;
			var endTime:uint = getTimer()+frameTime;
			while (!isComplete && endTime>getTimer())
			{
				isComplete = encodeBlock();
			}
			return isComplete;
		}
		
		private function cleanUp():void
		{
			_encodedBytes.position = 0;
			_isRunning = false;
			removeEventListener(Event.ENTER_FRAME, enterFrameHandler);
		}
		
		/**
		 * Called internally before multi-frame loop begins.
		 * 
		 * <p>Override to implement actions that need to be run once per image, before the asynchronous looping begins.</p>
		 */
		protected function encodeHead():void
		{
		}
		
		/**
		 * Called internally during multi-frame loop.
		 * 
		 * <p>Override to implement repeated actions. This method will be called repeatedly on every frame until the frame time is exceeded or <code>true</code> is returned.</p>
		 * <p>The bulk of encoder processing should be contained within this method.</p>
		 * <ul>
		 * <li>Use <code>currentX</code> and <code>currentY</code> to keep track of current position in source BitmapData.</li>
		 * <li>Update <code>completedPixels</code> here to ensure that progress events dispatch accurate values.</li>
		 * </ul>
		 * 
		 * @return True if loop processing has completed.
		 */
		protected function encodeBlock():Boolean
		{
			return true;
		}
		
		/**
		 * Called internally after multi-frame loop ends.
		 * 
		 * <p>Override to implement actions that need to be run once per image, after asynchronous looping has completed.</p>
		 */
		protected function encodeTail():void
		{
		}
		
	}
}